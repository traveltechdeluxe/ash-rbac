defmodule TestInvalidIam do
  use Ash.Resource,
    domain: AshRbac.IamTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshRbac]

  attributes do
    uuid_primary_key :id
  end

  rbac do
    iam do
      # This should fail because permission_base is required but not provided
      action_map %{create: :create}
    end
  end
end
