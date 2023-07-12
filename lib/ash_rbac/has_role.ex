defmodule AshRbac.HasRole do
  @moduledoc """
  Check to determine if the actor has a specific role or if the actor has any of the roles in a list
  """
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(options) do
    if is_list(options[:role]) do
      "Checks if the actor has any of the roles #{inspect(options[:role])}"
    else
      "Checks if the actor has the role #{inspect(options[:role])}"
    end
  end

  @impl true
  def match?(actor, _, options) do
    match(options[:role], actor)
  end

  defp match(roles, actor) when is_list(roles) do
    MapSet.size(MapSet.intersection(MapSet.new(roles), MapSet.new(roles(actor)))) > 0
  end

  defp match(roles, actor), do: match([roles], actor)

  defp roles(%{roles: roles}) when is_list(roles), do: roles
  defp roles(_), do: []
end
