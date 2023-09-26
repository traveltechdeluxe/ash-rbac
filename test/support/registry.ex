defmodule AshRbacTest.Registry do
  @moduledoc false
  use Ash.Registry

  entries do
    entry AshRbacTest.ChildResource
    entry AshRbacTest.OtherResource
    entry AshRbacTest.RootResource
    entry AshRbacTest.SharedResource
  end
end
