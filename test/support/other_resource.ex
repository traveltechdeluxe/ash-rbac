defmodule AshRbacTest.OtherResource do
  @moduledoc """
  Just used for compile time checking of some things
  """

  use Ash.Resource,
    domain: AshRbacTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshRbac]

  alias AshRbacTest.RootResource

  ets do
    private?(true)
  end

  rbac do
    role :user do
      fields [
        :root_id,
        :created_at,
        :updated_at
      ]

      actions [
        {:read, accessing_from(RootResource, :child)}
      ]
    end

    role :guest do
      roles_field :guest_roles

      actions [
        {:read, [accessing_from(RootResource, :child), accessing_from(RootResource, :child)]}
      ]
    end
  end

  field_policies do
    field_policy :field_with_custom_field_policy do
      authorize_if always()
    end
  end

  actions do
    default_accept [:*]
    defaults([:create, :read, :update, :destroy])
  end

  attributes do
    uuid_primary_key :id

    attribute :root_id, :uuid, public?: true

    attribute :field_with_custom_field_policy, :string, public?: true
    # an attribute that doesn't have a field policy
    # and isn't listed in any rbac role block
    # the extension still needs to add a policy
    # because all fields need to have a policy
    attribute :field_without_policy, :string, public?: true

    create_timestamp(:created_at, public?: true)
    update_timestamp(:updated_at, public?: true)
  end
end
