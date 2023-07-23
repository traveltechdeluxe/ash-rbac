defmodule AshRbac.HasRole do
  @moduledoc """
  Check to determine if the actor has a specific role or if the actor has any of the roles in a list
  """
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(options) do
    options[:role]
    |> Enum.map(fn {roles_field, roles} ->
      if Enum.count(roles) > 1 do
        "any of the roles #{inspect(roles)} for field #{inspect(roles_field)}"
      else
        "the role #{inspect(Enum.at(roles, 0))} for field #{inspect(roles_field)}"
      end
    end)
    |> Enum.join(" or ")
    |> then(& "Checks if the actor has #{&1}")
  end

  @impl true
  def match?(actor, _, options) do
    Enum.any?(options[:role], fn {roles_field, role} ->
      match(role, actor, roles_field)
    end)
  end

  defp match(roles, actor, roles_field) when is_list(roles) do
    roles -- roles(actor, roles_field) != roles
  end

  defp match(roles, actor, roles_field), do: match([roles], actor, roles_field)

  defp roles(actor, roles_field), do: actor |> Map.get(roles_field) |> roles()

  defp roles(roles) when is_list(roles), do: roles
  defp roles(_), do: []
end
