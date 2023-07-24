defmodule AshRbacTest.ChildResource do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshRbac]

  alias Ash.Policy.Check.Builtins
  alias AshRbacTest.RootResource

  ets do
    private?(true)
  end

  rbac do
    bypass :super_admin

    role :user do
      fields [:root_id, :created_at, :updated_at]

      actions [
        {:read, Builtins.accessing_from(RootResource, :child)}
      ]
    end

    role :guest do
      roles_field :guest_roles

      actions [
        {:read, Builtins.accessing_from(RootResource, :child)}
      ]
    end
  end

  actions do
    defaults([:create, :read, :update, :destroy])
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:root_id, :uuid)

    create_timestamp(:created_at, private?: false)
    update_timestamp(:updated_at, private?: false)
  end
end
