defmodule AshRbac.Role do
  @moduledoc """
  The Role entity for the DSL of the rbac extension
  """
  defstruct [:role, :options, :fields, :actions]
end
