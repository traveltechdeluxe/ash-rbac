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

    dsl_state =
      dsl_state
      |> add_field_policies(field_settings, bypass)
      |> add_bypass(bypass)

    {:ok,
     case Info.public?(dsl_state) do
       false ->
         dsl_state
         |> add_action_policies(action_settings)

       true ->
         dsl_state
         |> add_allow_policy()
     end
     |> then(fn dsl_state ->
       if String.contains?(
            Atom.to_string(get_in(dsl_state, [:persist, :module])),
            "PolicyTestSupport"
          ) do
         dsl_state
         |> IO.inspect(label: "DSL STATE")
       else
         dsl_state
       end
     end)}
  end

  defp transform_options(dsl_state) do
    Info.roles(dsl_state)
    |> List.wrap()
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

  defp add_bypass(dsl_state, role) do
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
    |> Enum.reduce(dsl_state, fn {field, roles}, dsl_state ->
      add_role_action_policies(
        dsl_state,
        field,
        roles
      )
    end)
  end

  defp add_role_action_policies(dsl_state, action, roles) do
    role_checks =
      roles
      |> Enum.map(fn role ->
        {:ok, role_check} =
          Transformer.build_entity(
            Ash.Policy.Authorizer,
            [:policies, :policy],
            :authorize_if,
            check: {AshRbac.HasRole, [role: role]}
          )

        role_check
      end)

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies], :policy,
        condition: Builtins.action(action),
        policies: role_checks
      )

    dsl_state
    |> Transformer.add_entity([:policies], policy, type: :append)
  end

  defp add_field_policies(dsl_state, field_settings, bypass) do
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
      add_role_field_policies(
        dsl_state,
        field,
        Map.get(field_settings, field, []),
        bypass
      )
    end)
  end

  defp add_role_field_policies(dsl_state, field, roles, bypass) do
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

    {:ok, bypass_check} =
      if bypass do
        Transformer.build_entity(
          Ash.Policy.Authorizer,
          [:field_policies, :field_policy],
          :authorize_if,
          check: {AshRbac.HasRole, [role: bypass]}
        )
      else
        {:ok, nil}
      end

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
        policies:
          bypass_check |> List.wrap() |> Enum.concat(role_checks) |> Enum.concat([default_check])
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
