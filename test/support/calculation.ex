defmodule AshRbacTest.Calculation do
  @moduledoc false
  use Ash.Resource.Calculation

  @impl true
  def calculate(records, _, _) do
    Enum.map(records, fn _ -> 1 end)
  end
end
