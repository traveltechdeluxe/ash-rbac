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
    bypass_roles_field = Info.bypass_roles_field(dsl_state)

    {:ok,
     case Info.public?(dsl_state) do
       false ->
         dsl_state
         |> add_field_policies(field_settings)
         |> add_action_policies(action_settings)
         |> add_bypass(bypass, bypass_roles_field)

       true ->
         dsl_state
         |> add_allow_policy()
     end}
  end

  defp transform_options(dsl_state) do
    all_fields = all_fields(dsl_state)

    Info.roles(dsl_state)
    |> List.wrap()
    |> Enum.flat_map(fn %AshRbac.Role{role: role} = entity ->
      role
      |> List.wrap()
      |> Enum.map(fn role ->
        %{entity | role: role}
      end)
    end)
    |> Enum.reduce({%{}, %{}}, fn %{
                                    role: role,
                                    fields: fields,
                                    roles_field: roles_field,
                                    actions: actions
                                  },
                                  {field_settings, action_settings} ->
      roles_field = roles_field || :roles

      field_settings =
        fields
        |> List.wrap()
        |> Enum.reject(&(&1 not in [:* | all_fields]))
        |> Enum.reduce(field_settings, fn
          :*, acc ->
            all_fields
            |> Enum.reduce(acc, fn field, acc ->
              Map.update(acc, field, [{role, roles_field}], fn roles ->
                [{role, roles_field} | roles]
              end)
            end)

          field, acc ->
            Map.update(acc, field, [{role, roles_field}], fn roles ->
              [{role, roles_field} | roles]
            end)
        end)

      {
        field_settings,
        actions
        |> List.wrap()
        |> Enum.reduce(action_settings, fn action, acc ->
          Map.update(acc, action, [{role, roles_field}], fn roles ->
            [{role, roles_field} | roles]
          end)
        end)
      }
    end)
    |> then(fn {field_settings, action_settings} ->
      {group_field_settings(field_settings, all_fields), action_settings}
    end)
  end

  defp group_field_settings(field_settings, all_fields) do
    policy_fields = Map.keys(field_settings)

    grouped_field_settings = group_field_settings(field_settings)

    missing_fields = all_fields -- policy_fields

    grouped_field_settings
    |> then(fn grouped_field_settings ->
      if Enum.count(missing_fields) > 0 do
        grouped_field_settings |> Map.put(missing_fields, [])
      else
        grouped_field_settings
      end
    end)
  end

  defp group_field_settings(field_settings) do
    field_settings
    |> Enum.group_by(fn {_, value} -> value end, fn {key, _} -> key end)
    |> Enum.into(%{}, fn {roles, fields} -> {List.flatten(fields), List.flatten(roles)} end)
  end

  defp add_bypass(dsl_state, nil, _), do: dsl_state

  defp add_bypass(dsl_state, role, roles_field),
    do: dsl_state |> add_field_bypass(role, roles_field) |> add_action_bypass(role, roles_field)

  defp add_field_bypass(dsl_state, role, roles_field) do
    {:ok, check} =
      Transformer.build_entity(
        Ash.Policy.Authorizer,
        [:field_policies, :field_policy_bypass],
        :authorize_if,
        check: {AshRbac.HasRole, [role: [{roles_field, role}]]}
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:field_policies], :field_policy_bypass,
        fields: :*,
        condition: [Builtins.always()],
        policies: [check]
      )

    dsl_state
    |> Transformer.add_entity([:field_policies], policy, type: :prepend)
  end

  defp add_action_bypass(dsl_state, role, roles_field) do
    {:ok, check} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies, :bypass], :authorize_if,
        check: Builtins.always()
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies], :bypass,
        condition: [{AshRbac.HasRole, [role: [{roles_field, role}]]}],
        policies: [check]
      )

    dsl_state
    |> Transformer.add_entity([:policies], policy, type: :prepend)
  end

  defp add_action_policies(dsl_state, action_settings) when action_settings == %{}, do: dsl_state

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

  defp add_role_action_policies(dsl_state, {action, custom_condition}, roles) do
    {:ok, role_check} =
      Transformer.build_entity(
        Ash.Policy.Authorizer,
        [:policies, :policy],
        :authorize_if,
        check: {AshRbac.HasRole, [role: group_roles(roles)]}
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies], :policy,
        condition: [Builtins.action(action), custom_condition],
        policies: [role_check]
      )

    dsl_state
    |> Transformer.add_entity([:policies], policy, type: :append)
  end

  defp add_role_action_policies(dsl_state, action, roles) do
    {:ok, role_check} =
      Transformer.build_entity(
        Ash.Policy.Authorizer,
        [:policies, :policy],
        :authorize_if,
        check: {AshRbac.HasRole, [role: group_roles(roles)]}
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies], :policy,
        condition: [Builtins.action(action)],
        policies: [role_check]
      )

    dsl_state
    |> Transformer.add_entity([:policies], policy, type: :append)
  end

  defp add_field_policies(dsl_state, field_settings) when field_settings == %{}, do: dsl_state

  defp add_field_policies(dsl_state, field_settings) do
    field_settings
    |> Enum.reduce(dsl_state, fn {fields, roles}, dsl_state ->
      add_role_field_policies(
        dsl_state,
        fields,
        roles
      )
    end)
  end

  defp add_role_field_policies(dsl_state, fields, []) do
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

  defp add_role_field_policies(dsl_state, fields, roles) do
    {:ok, role_check} =
      Transformer.build_entity(
        Ash.Policy.Authorizer,
        [:field_policies, :field_policy],
        :authorize_if,
        check: {AshRbac.HasRole, [role: group_roles(roles)]}
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:field_policies], :field_policy,
        fields: fields,
        condition: [Builtins.always()],
        policies: [role_check]
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

  def after?(Ash.Policy.Authorizer), do: true
  def after?(_), do: false

  defp group_roles(roles) do
    roles
    |> Enum.group_by(fn {_, field} -> field end, fn {role, _} -> role end)
    |> Enum.to_list()
    # check the fields with the most roles first
    # higher chance of early return
    |> Enum.sort_by(fn {_, roles} -> Enum.count(roles) end, &>=/2)
  end
end
