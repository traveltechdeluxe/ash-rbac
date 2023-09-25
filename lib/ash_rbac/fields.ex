defmodule AshRbac.Fields do
  @moduledoc """
  Adds the policies for fields to the dsl_state
  """

  use Spark.Dsl.Transformer

  alias Ash.Policy.Check.Builtins
  alias AshRbac.Info
  alias Spark.Dsl.Transformer

  @impl true
  def transform(dsl_state) do
    field_settings =
      Info.roles(dsl_state)
      |> group_field_settings(all_fields(dsl_state), custom_policy_fields(dsl_state))

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

  defp group_field_settings(roles, all_fields, custom_policy_fields) do
    roles
    |> prepare_data_for_grouping(all_fields)
    |> Enum.reduce(%{}, fn %{role: role, fields: fields, condition: condition}, acc ->
      fields = MapSet.new(fields)

      acc
      |> Map.update(condition, %{(fields |> Enum.to_list()) => List.wrap(role)}, fn existing ->
        {acc, _, new_fields} =
          existing
          |> Map.keys()
          |> Enum.reduce({%{}, MapSet.new(), fields}, fn existing_fields,
                                                         {acc, already_added_fields, new_fields} ->
            existing_fields_set = MapSet.new(existing_fields)

            shared_fields = MapSet.intersection(new_fields, existing_fields_set)

            extra_existing_fields = MapSet.difference(existing_fields_set, shared_fields)

            extra_new_fields = MapSet.difference(new_fields, shared_fields)

            {acc
             |> maybe_add_fields(
               shared_fields |> Enum.to_list(),
               List.wrap(Map.get(existing, existing_fields) ++ List.wrap(role))
             )
             |> maybe_add_fields(
               extra_existing_fields |> Enum.to_list(),
               List.wrap(Map.get(existing, existing_fields))
             ),
             shared_fields
             |> Enum.reduce(already_added_fields, fn shared_field, already_added_fields ->
               MapSet.put(already_added_fields, shared_field)
             end), extra_new_fields}
          end)

        acc
        |> maybe_add_fields(new_fields |> Enum.to_list(), List.wrap(role))
      end)
    end)
    |> Enum.flat_map(fn
      {nil, fields} ->
        fields
        |> Enum.map(fn {fields, roles} ->
          {fields, roles}
        end)

      {condition, fields} ->
        fields
        |> Enum.map(fn {fields, roles} ->
          {fields, condition, roles}
        end)
    end)
    |> then(fn field_settings ->
      missing_fields = missing_fields(field_settings, all_fields, custom_policy_fields)

      if Enum.count(missing_fields) > 0 do
        [{missing_fields, []} | field_settings]
      else
        field_settings
      end
    end)
  end

  # Takes in all roles and transforms them into the following format
  #
  #  input: [
  #    %AshRbac.Role{
  #      role: [:admin, "admin"],
  #      roles_field: nil,
  #      fields: [:*],
  #      actions: [:create, :read]
  #    },
  #    %AshRbac.Role{
  #      role: :user,
  #      roles_field: nil,
  #      fields: [
  #        :root_id,
  #        :basic_field,
  #        {:only_accessible_for_user_if_coming_from_root_resource,
  #         {Ash.Policy.Check.AccessingFrom,
  #          [source: AshRbacTest.RootResource, relationship: :shared_resource]}}
  #      ],
  #      actions: [:read]
  #    }
  #  ]
  #
  #  output: [
  #    %{
  #      condition: nil,
  #      fields: [
  #        :basic_field,
  #        :only_accessible_for_user_if_coming_from_root_resource,
  #        :created_at,
  #        :updated_at
  #      ],
  #      role: [:admin, "admin"]
  #    },
  #    %{condition: nil, fields: [:basic_field], role: :user},
  #    %{
  #      condition:
  #        {Ash.Policy.Check.AccessingFrom,
  #         [source: AshRbacTest.RootResource, relationship: :shared_resource]},
  #      fields: [:only_accessible_for_user_if_coming_from_root_resource],
  #      role: :user
  #    }
  #  ]

  defp prepare_data_for_grouping(roles, all_fields) do
    roles
    |> Enum.flat_map(fn %AshRbac.Role{fields: fields} = role ->
      fields
      |> List.wrap()
      |> Enum.reduce(%{}, fn
        field, acc when is_atom(field) ->
          Map.update(acc, :no_condition, [field], &(&1 ++ [field]))

        {field, condition}, acc ->
          Map.update(acc, condition, field |> List.wrap(), &(&1 ++ (field |> List.wrap())))
      end)
      |> Enum.map(fn
        {:no_condition, fields} ->
          %{role: create_role(role), fields: fields, condition: nil}

        {condition, fields} ->
          %{role: create_role(role), fields: fields, condition: condition}
      end)
      |> Enum.map(fn %{fields: fields} = field_settings ->
        %{field_settings | fields: sanitize_fields(fields, all_fields)}
      end)
    end)
  end

  defp maybe_add_fields(acc, [], _), do: acc
  defp maybe_add_fields(acc, fields, roles), do: Map.put(acc, fields, roles)

  defp sanitize_fields(fields, all_fields) do
    fields
    |> List.wrap()
    |> Enum.reject(&(&1 not in [:* | all_fields]))
    |> Enum.flat_map(fn
      :* ->
        all_fields

      field ->
        [field]
    end)
    |> Enum.uniq()
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

  defp missing_fields(field_settings, all_fields, custom_policy_fields) do
    fields_that_have_a_policy =
      field_settings
      |> Enum.flat_map(fn
        {fields, _, _} ->
          fields

        {fields, _} ->
          fields
      end)
      |> Enum.uniq()

    (all_fields -- fields_that_have_a_policy) -- custom_policy_fields
  end

  defp create_role(%{role: role, roles_field: nil}), do: role
  defp create_role(%{role: role, roles_field: roles_field}), do: {roles_field, role}
end
