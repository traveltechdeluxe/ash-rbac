defmodule AshRbacTest.RootResource do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshRbac]

  alias AshRbacTest.Calculation
  alias AshRbacTest.ChildResource

  ets do
    private?(true)
  end

  rbac do
    bypass :super_admin

    role :admin do
      fields [:*]
      actions [:create, :read]
    end

    role :user do
      fields [:id, :child, :children, :number]
      actions [:read]
    end

    role :guest do
      roles_field :guest_roles
      fields [:children]
      actions [:read]
    end
  end

  actions do
    defaults([:create, :read, :update, :destroy])
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:admin_only, :integer, default: 2)

    create_timestamp(:created_at, private?: false)
    update_timestamp(:updated_at, private?: false)
  end

  relationships do
    has_one :child, ChildResource do
      source_attribute(:id)
      destination_attribute(:root_id)
    end

    has_one :admin_only_child, ChildResource do
      source_attribute(:id)
      destination_attribute(:root_id)
    end

    belongs_to :shared_resource, AshRbacTest.SharedResource do
      source_attribute :shared_resource_id
      destination_attribute :id
      attribute_writable? true
    end
  end

  aggregates do
    count(:children, :child)
    count(:admin_only_children, :child)
  end

  calculations do
    calculate(:number, :integer, Calculation)
    calculate(:admin_only_number, :integer, Calculation)
  end
end
