defmodule AshRbac.Policies do
  @moduledoc """
  Adds the configured policies to the resource
  """

  use Spark.Dsl.Transformer

  alias Ash.Policy.Check.Builtins
  alias AshRbac.Info
  alias Spark.Dsl.Transformer

  def transform(dsl_state) do
    {field_settings, action_settings} = transform_options(dsl_state)
    bypass = Info.bypass(dsl_state)

    {:ok,
     case Info.public?(dsl_state) do
       false ->
         dsl_state
         |> add_field_policies(field_settings)
         |> add_action_policies(action_settings)
         |> add_bypass(bypass)

       true ->
         dsl_state
         |> add_allow_policy()
     end}
  end

  defp transform_options(dsl_state) do
    Info.roles(dsl_state)
    |> List.wrap()
    |> Enum.flat_map(fn %AshRbac.Role{role: role} = entity ->
      role
      |> List.wrap()
      |> Enum.map(fn role ->
        %{entity | role: role}
      end)
    end)
    |> Enum.reduce({%{}, %{}}, fn %{role: role, fields: fields, actions: actions},
                                  {field_settings, action_settings} ->
      {
        fields
        |> List.wrap()
        |> Enum.reduce(field_settings, fn field, acc ->
          Map.update(acc, field, [role], fn roles ->
            [role | roles]
          end)
        end),
        actions
        |> List.wrap()
        |> Enum.reduce(action_settings, fn action, acc ->
          Map.update(acc, action, [role], fn roles ->
            [role | roles]
          end)
        end)
      }
    end)
  end

  defp add_bypass(dsl_state, nil), do: dsl_state

  defp add_bypass(dsl_state, role),
    do: dsl_state |> add_field_bypass(role) |> add_action_bypass(role)

  defp add_field_bypass(dsl_state, role) do
    {:ok, check} =
      Transformer.build_entity(
        Ash.Policy.Authorizer,
        [:field_policies, :field_policy_bypass],
        :authorize_if,
        check: {AshRbac.HasRole, [role: role]}
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:field_policies], :field_policy_bypass,
        fields: :*,
        condition: Builtins.always(),
        policies: [check]
      )

    dsl_state
    |> Transformer.add_entity([:field_policies], policy, type: :prepend)
  end

  defp add_action_bypass(dsl_state, role) do
    {:ok, check} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies, :bypass], :authorize_if,
        check: Builtins.always()
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies], :bypass,
        condition: {AshRbac.HasRole, [role: role]},
        policies: [check]
      )

    dsl_state
    |> Transformer.add_entity([:policies], policy, type: :prepend)
  end

  defp add_action_policies(dsl_state, action_settings) do
    action_settings
    |> Enum.reduce(dsl_state, fn
      {action, roles}, dsl_state ->
        add_role_action_policies(
          dsl_state,
          action,
          roles
        )
    end)
  end

  defp add_role_action_policies(dsl_state, {action, custom_check}, roles) do
    {:ok, authorize_check} =
      Transformer.build_entity(
        Ash.Policy.Authorizer,
        [:policies, :policy],
        :authorize_if,
        check: Builtins.always()
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies], :policy,
        condition: [Builtins.action(action), {AshRbac.HasRole, [role: roles]}, custom_check],
        policies: [authorize_check]
      )

    dsl_state
    |> Transformer.add_entity([:policies], policy, type: :append)
  end

  defp add_role_action_policies(dsl_state, action, roles) do
    {:ok, authorize_check} =
      Transformer.build_entity(
        Ash.Policy.Authorizer,
        [:policies, :policy],
        :authorize_if,
        check: Builtins.always()
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies], :policy,
        condition: [Builtins.action(action), {AshRbac.HasRole, [role: roles]}],
        policies: [authorize_check]
      )

    dsl_state
    |> Transformer.add_entity([:policies], policy, type: :append)
  end

  defp add_field_policies(dsl_state, field_settings) do
    all_fields_roles = Map.get(field_settings, :*, [])

    all_fields =
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

    all_fields
    |> Enum.reduce(dsl_state, fn field, dsl_state ->
      roles =
        field_settings
        |> Map.get(field, [])
        |> Enum.concat(all_fields_roles)

      add_role_field_policies(
        dsl_state,
        field,
        roles
      )
    end)
  end

  defp add_role_field_policies(dsl_state, field, roles) do
    role_checks =
      roles
      |> Enum.map(fn role ->
        {:ok, role_check} =
          Transformer.build_entity(
            Ash.Policy.Authorizer,
            [:field_policies, :field_policy],
            :authorize_if,
            check: {AshRbac.HasRole, [role: role]}
          )

        role_check
      end)

    {:ok, default_check} =
      Transformer.build_entity(
        Ash.Policy.Authorizer,
        [:field_policies, :field_policy],
        :forbid_if,
        check: Builtins.always()
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:field_policies], :field_policy,
        fields: field,
        condition: Builtins.always(),
        policies: Enum.concat(role_checks, [default_check])
      )

    dsl_state
    |> Transformer.add_entity([:field_policies], policy, type: :append)
  end

  defp add_allow_policy(dsl_state) do
    {:ok, check} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies, :policy], :authorize_if,
        check: Builtins.always()
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies], :policy,
        condition: Builtins.always(),
        policies: [check]
      )

    dsl_state
    |> Transformer.add_entity([:policies], policy, type: :append)
  end

  def after?(Ash.Policy.Authorizer), do: true
  def after?(_), do: false
end
