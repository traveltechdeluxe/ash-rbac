defmodule AshRbacTest.RootResource do
  @moduledoc false
  use Ash.Resource,
    domain: AshRbacTest.Domain,
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
      fields [:id, :child, :children, :number, :shared_resource_id]
      actions [:read]
    end

    role :guest do
      roles_field :guest_roles
      fields [:children]
      actions [:read]
    end
  end

  actions do
    default_accept [:*]
    defaults([:create, :read, :update, :destroy])
  end

  attributes do
    uuid_primary_key :id

    attribute :admin_only, :integer, default: 2, public?: true

    attribute :no_field_policy, :integer, default: 1, public?: true

    create_timestamp(:created_at, public?: true)
    update_timestamp(:updated_at, public?: true)
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
      attribute_public? true
    end
  end

  aggregates do
    count(:children, :child, public?: true)
    count(:admin_only_children, :child, public?: true)
  end

  calculations do
    calculate(:number, :integer, Calculation, public?: true)
    calculate(:admin_only_number, :integer, Calculation, public?: true)
  end
end
