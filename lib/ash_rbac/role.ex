defmodule AshRbac.Role do
  @moduledoc """
  The Role entity for the DSL of the rbac extension
  """
  defstruct [:role, :roles_field, :fields, :actions]
end
