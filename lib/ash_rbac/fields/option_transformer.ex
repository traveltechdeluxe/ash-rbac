defmodule AshRbac.Fields.OptionTransformer do
  @moduledoc false

  def group_field_settings(roles, all_fields, custom_policy_fields) do
    roles
    |> prepare_data_for_grouping(all_fields)
    |> group_by_condition_and_fields()
    |> create_policy_input_from_groups()
    |> add_policy_input_for_missing_fields(all_fields, custom_policy_fields)
  end

  @doc ~S"""
  Takes in all roles and transforms them into the following format

      iex> AshRbac.Fields.OptionTransformer.prepare_data_for_grouping([
      ...>   %AshRbac.Role{
      ...>     role: [:admin, "admin"],
      ...>     roles_field: nil,
      ...>     fields: [:*],
      ...>     actions: [:create, :read]
      ...>   },
      ...>   %AshRbac.Role{
      ...>     role: :user,
      ...>     roles_field: nil,
      ...>     fields: [
      ...>       :root_id,
      ...>       :basic_field,
      ...>       {:only_accessible_for_user_if_coming_from_root_resource,
      ...>        {Ash.Policy.Check.AccessingFrom,
      ...>         [source: AshRbacTest.RootResource, relationship: :shared_resource]}}
      ...>     ],
      ...>     actions: [:read]
      ...>   }
      ...> ], [:basic_field, :only_accessible_for_user_if_coming_from_root_resource, :created_at, :updated_at])
      [
        %{
          condition: nil,
          fields: [
            :basic_field,
            :only_accessible_for_user_if_coming_from_root_resource,
            :created_at,
            :updated_at
          ],
          role: [:admin, "admin"]
        },
        %{condition: nil, fields: [:basic_field], role: :user},
        %{
          condition:
            {Ash.Policy.Check.AccessingFrom,
             [source: AshRbacTest.RootResource, relationship: :shared_resource]},
          fields: [:only_accessible_for_user_if_coming_from_root_resource],
          role: :user
        }
      ]
  """
  def prepare_data_for_grouping(roles, all_fields) do
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

  @doc ~S"""
  Groups the policy settings by condition -> fields -> user

  iex> AshRbac.Fields.OptionTransformer.group_by_condition_and_fields([
  ...>  %{
  ...>    condition: nil,
  ...>    fields: [
  ...>      :basic_field,
  ...>      :only_accessible_for_user_if_coming_from_root_resource,
  ...>      :created_at,
  ...>      :updated_at
  ...>    ],
  ...>    role: [:admin, "admin"]
  ...>  },
  ...>  %{condition: nil, fields: [:basic_field], role: :user},
  ...>  %{
  ...>    condition:
  ...>      {Ash.Policy.Check.AccessingFrom,
  ...>       [source: AshRbacTest.RootResource, relationship: :shared_resource]},
  ...>    fields: [:only_accessible_for_user_if_coming_from_root_resource],
  ...>    role: :user
  ...>  },
  ...>  %{condition: nil, fields: [:basic_field], role: {:guest_roles, :guest}}
  ...>])
  %{
    nil => %{
      [:basic_field] => [:admin, "admin", :user, {:guest_roles, :guest}],
      [:created_at, :only_accessible_for_user_if_coming_from_root_resource, :updated_at] => [
        :admin,
        "admin"
      ]
    },
    {Ash.Policy.Check.AccessingFrom,
     [source: AshRbacTest.RootResource, relationship: :shared_resource]} => %{
      [:only_accessible_for_user_if_coming_from_root_resource] => [:user]
    }
  }
  """
  def group_by_condition_and_fields(settings) do
    settings
    |> Enum.reduce(%{}, fn %{role: role, fields: fields, condition: condition}, acc ->
      fields = MapSet.new(fields)

      acc
      |> Map.update(condition, %{(fields |> Enum.to_list()) => List.wrap(role)}, fn existing ->
        {acc, fields_still_without_policy} =
          existing
          |> Map.keys()
          |> Enum.reduce({%{}, fields}, fn existing_fields, {acc, new_fields} ->
            existing_fields_set = MapSet.new(existing_fields)

            shared_fields = MapSet.intersection(new_fields, existing_fields_set)

            extra_existing_fields = MapSet.difference(existing_fields_set, shared_fields)

            fields_still_without_policy = MapSet.difference(new_fields, shared_fields)

            {acc
             |> maybe_add_fields(
               shared_fields |> Enum.to_list(),
               List.wrap(Map.get(existing, existing_fields) ++ List.wrap(role))
             )
             |> maybe_add_fields(
               extra_existing_fields |> Enum.to_list(),
               List.wrap(Map.get(existing, existing_fields))
             ), fields_still_without_policy}
          end)

        acc
        |> maybe_add_fields(fields_still_without_policy |> Enum.to_list(), List.wrap(role))
      end)
    end)
  end

  @doc ~S"""
  Creates one tuple per policy that needs to be applied


  iex> AshRbac.Fields.OptionTransformer.create_policy_input_from_groups(%{
  ...>  nil => %{
  ...>    [:basic_field] => [:admin, "admin", :user, {:guest_roles, :guest}],
  ...>    [:created_at, :only_accessible_for_user_if_coming_from_root_resource, :updated_at] => [
  ...>      :admin,
  ...>      "admin"
  ...>    ]
  ...>  },
  ...>  {Ash.Policy.Check.AccessingFrom,
  ...>   [source: AshRbacTest.RootResource, relationship: :shared_resource]} => %{
  ...>    [:only_accessible_for_user_if_coming_from_root_resource] => [:user]
  ...>  }
  ...>})
  [
    {[:basic_field], [:admin, "admin", :user, {:guest_roles, :guest}]},
    {[:created_at, :only_accessible_for_user_if_coming_from_root_resource, :updated_at],
      [:admin, "admin"]},
    {[:only_accessible_for_user_if_coming_from_root_resource],
      {Ash.Policy.Check.AccessingFrom,
      [source: AshRbacTest.RootResource, relationship: :shared_resource]}, [:user]}
  ]
  """
  def create_policy_input_from_groups(groups) do
    groups
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
  end

  defp add_policy_input_for_missing_fields(field_settings, all_fields, custom_policy_fields) do
    missing_fields = missing_fields(field_settings, all_fields, custom_policy_fields)

    if Enum.count(missing_fields) > 0 do
      [{missing_fields, []} | field_settings]
    else
      field_settings
    end
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

  defp create_role(%{role: role, roles_field: nil}), do: role
  defp create_role(%{role: role, roles_field: roles_field}), do: {roles_field, role}

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
end
