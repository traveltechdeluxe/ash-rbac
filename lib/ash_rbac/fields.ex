defmodule AshRbac.Fields do
  @moduledoc """
  Adds the configured field policies to the resource
  """

  use Spark.Dsl.Transformer

  alias AshRbac.Info

  @impl true
  def transform(dsl_state) do
    Info.roles(dsl_state)
    |> Enum.flat_map(fn %AshRbac.Role{fields: fields} = role ->
      fields
      |> Enum.reduce(%{}, fn
        field, acc when is_atom(field) ->
          Map.update(acc, :no_condition, [field], &(&1 ++ [field]))

        {field, condition}, acc ->
          Map.update(acc, condition, field |> List.wrap(), &(&1 ++ (field |> List.wrap())))
      end)
      |> Enum.map(fn
        {:no_condition, fields} ->
          %{role: role.role, fields: fields, condition: nil}

        {condition, fields} ->
          %{role: role.role, fields: fields, condition: condition}
      end)
      |> Enum.map(fn %{fields: fields} = field_settings ->
        %{field_settings | fields: sanitize_fields(fields, dsl_state)}
      end)
    end)
    |> Enum.reduce(%{}, fn %{role: role, fields: fields, condition: condition}, acc ->
      fields = MapSet.new(fields)

      acc
      |> Map.update(condition, %{fields => List.wrap(role)}, fn existing ->
        existing
        |> Map.keys()
        |> Enum.reduce(%{}, fn existing_fields, acc ->
          existing_fields_set = MapSet.new(existing_fields)

          shared_fields = MapSet.intersection(fields, existing_fields_set)
          extra_existing_fields = MapSet.difference(existing_fields_set, shared_fields)
          extra_new_fields = MapSet.difference(fields, shared_fields)

          acc
          |> maybe_add_fields(
            shared_fields |> Enum.to_list(),
            List.wrap(Map.get(existing, existing_fields) ++ List.wrap(role))
          )
          |> maybe_add_fields(
            extra_existing_fields |> Enum.to_list(),
            List.wrap(Map.get(existing, existing_fields))
          )
          |> maybe_add_fields(extra_new_fields |> Enum.to_list(), List.wrap(role))
        end)
      end)
    end)
  end

  defp maybe_add_fields(acc, [], roles), do: acc
  defp maybe_add_fields(acc, fields, roles), do: Map.put(acc, fields, roles)

  defp sanitize_fields(fields, dsl_state) do
    all_fields = all_fields(dsl_state)

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
end
