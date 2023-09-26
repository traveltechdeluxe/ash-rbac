defmodule AshRbac.Fields do
  @moduledoc """
  Adds the policies for fields to the dsl_state
  """

  use Spark.Dsl.Transformer

  alias Ash.Policy.Check.Builtins
  alias AshRbac.Fields.RoleTransformer
  alias AshRbac.Info
  alias Spark.Dsl.Transformer

  @impl true
  def transform(dsl_state) do
    field_settings =
      Info.roles(dsl_state)
      |> RoleTransformer.roles_to_field_settings(
        all_fields(dsl_state),
        custom_policy_fields(dsl_state)
      )

    dsl_state
    |> add_field_policies(field_settings)
  end

  defp add_field_policies(dsl_state, field_settings) when field_settings == [], do: dsl_state

  defp add_field_policies(dsl_state, field_settings) do
    field_settings
    |> Enum.reduce(dsl_state, fn
      {fields, roles}, dsl_state ->
        add_role_field_policies(
          dsl_state,
          fields,
          nil,
          roles
        )

      {fields, condition, roles}, dsl_state ->
        add_role_field_policies(
          dsl_state,
          fields,
          condition,
          roles
        )
    end)
  end

  defp add_role_field_policies(dsl_state, fields, nil, []) do
    {:ok, forbid_check} =
      Transformer.build_entity(
        Ash.Policy.Authorizer,
        [:field_policies, :field_policy],
        :forbid_if,
        check: Builtins.always()
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:field_policies], :field_policy,
        fields: fields,
        condition: [Builtins.always()],
        policies: [forbid_check]
      )

    dsl_state
    |> Transformer.add_entity([:field_policies], policy, type: :append)
  end

  defp add_role_field_policies(dsl_state, fields, nil, roles) do
    {:ok, role_check} =
      Transformer.build_entity(
        Ash.Policy.Authorizer,
        [:field_policies, :field_policy],
        :authorize_if,
        check: [Builtins.always()]
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:field_policies], :field_policy,
        fields: fields,
        condition: [{AshRbac.HasRole, [role: roles]}],
        policies: [role_check]
      )

    dsl_state
    |> Transformer.add_entity([:field_policies], policy, type: :append)
  end

  defp add_role_field_policies(dsl_state, fields, condition, roles) do
    {:ok, role_check} =
      Transformer.build_entity(
        Ash.Policy.Authorizer,
        [:field_policies, :field_policy],
        :authorize_if,
        check: [Builtins.always()]
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:field_policies], :field_policy,
        fields: fields,
        condition: List.wrap(condition) ++ [{AshRbac.HasRole, [role: roles]}],
        policies: [role_check]
      )

    dsl_state
    |> Transformer.add_entity([:field_policies], policy, type: :append)
  end

  defp all_fields(dsl_state) do
    dsl_state
    |> Ash.Resource.Info.fields([:attributes, :calculations, :aggregates])
    |> Enum.reject(fn
      %{primary_key?: true} ->
        true

      %{private?: true} ->
        true

      _ ->
        false
    end)
    |> Enum.map(& &1.name)
  end

  defp custom_policy_fields(dsl_state) do
    dsl_state
    |> Ash.Policy.Info.field_policies()
    |> Enum.flat_map(& &1.fields)
  end
end
