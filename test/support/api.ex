defmodule AshRbacTest.Api do
  @moduledoc false
  use Ash.Api

  resources do
    registry(AshRbacTest.Registry)
  end
end
