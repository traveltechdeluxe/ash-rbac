defmodule AshRbacTest.SharedResource do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshRbac]

  ets do
    private?(true)
  end

  rbac do
    bypass :super_admin

    role [:admin, "admin"] do
      fields [:*]
      actions [:create, :read]
    end

    role :user do
      fields [
        :root_id,
        :basic_field,
        {:only_accessible_for_user_if_coming_from_root_resource,
         accessing_from(AshRbacTest.RootResource, :shared_resource)}
      ]

      actions [:read]
    end

    role :guest do
      roles_field :guest_roles

      fields [:basic_field]
    end
  end

  actions do
    defaults([:create, :read, :update, :destroy])
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:basic_field, :integer, default: 2)

    attribute :only_accessible_for_user_if_coming_from_root_resource, :string

    create_timestamp(:created_at, private?: false)
    update_timestamp(:updated_at, private?: false)
  end
end
