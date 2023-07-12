defmodule PolicyTestSupport do
  @moduledoc """
  Simple Ash Project for policy testing
  """
  defmodule Calculation do
    @moduledoc false
    use Ash.Calculation

    @impl true
    def calculate(records, _, _) do
      Enum.map(records, fn _ -> 1 end)
    end
  end

  defmodule ChildResource do
    @moduledoc false
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer],
      extensions: [AshRbac]

    ets do
      private?(true)
    end

    rbac do
      role(:admin, [:root_id, :created_at, :updated_at]) do
        actions([
          {:read, Ash.Policy.Check.Builtins.accessing_from(RootResource, :admin_only_child)}
        ])
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

  defmodule RootResource do
    @moduledoc false
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer],
      extensions: [AshRbac]

    ets do
      private?(true)
    end

    rbac do
      bypass(:admin)

      role(:user, [:id, :child, :children, :number]) do
        actions([:create, :read, :update, :destroy])
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

  defmodule Registry do
    @moduledoc false
    use Ash.Registry

    entries do
      entry(RootResource)
      entry(ChildResource)
    end
  end

  defmodule Api do
    @moduledoc false
    use Ash.Api

    resources do
      registry(Registry)
    end
  end
end
