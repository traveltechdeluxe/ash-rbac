defmodule TestInvalidMapping do
  use Ash.Resource,
    domain: AshRbac.IamTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshRbac]

  attributes do
    uuid_primary_key :id
  end

  rbac do
    iam do
      permission_base "app:test"
      # This should fail because the value is not an atom
      action_to_iam_mapping create: "create"
    end
  end
end
