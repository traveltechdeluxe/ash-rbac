defmodule AshRbacTest.Registry do
  @moduledoc false
  use Ash.Registry

  entries do
    entry AshRbacTest.RootResource
    entry AshRbacTest.ChildResource
    entry AshRbacTest.SharedResource
  end
end
