defmodule AshRbac.HasRole do
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(options) do
    "Checks if the actor has the role #{inspect(options[:role])}"
  end

  @impl true
  def match?(actor, context, options) do
    options[:role] in Map.get(actor || %{}, :roles, [])
  end
end
