defmodule AshRbacTest.Domain do
  @moduledoc false
  use Ash.Domain

  resources do
    resource(AshRbacTest.ChildResource)
    resource(AshRbacTest.OtherResource)
    resource(AshRbacTest.RootResource)
    resource(AshRbacTest.SharedResource)
  end
end
