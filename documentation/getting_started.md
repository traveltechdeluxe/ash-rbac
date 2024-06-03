# Getting Started

## Installation

Add the ash_rbac dependency to your mix.exs

```elixir
defp deps do
  [
    {:ash_rbac, "~> 0.5.0"}
  ]
end
```

## Adding AshRbac to your resource

First, the authorizer and the extension need to be added.

```elixir
defmodule RootResource do
    @moduledoc false
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer], # Add the authorizer
      extensions: [AshRbac] # Add the extension
  ...
end
```

Afterwards, you can add a rbac block to your resource.

```elixir
  rbac do
    role :user do
      fields [:name, :email]
      actions [:read]
    end
  end
```

The options defined in the rbac block are transformed into policies during compile time.

The previous example will generate the following policies:

```elixir
field_policies do
  field_policy [:name, :email], [{AshRbac.HasRole, [role: [:user]]}] do
    authorize_if always()
  end

  # it also adds a policy for all other fields like this
  field_policy [:other_fields, ...] do
    forbid_if always()
  end
end

policies do
  policy [action(:read), {AshRbac.HasRole, [role: [:user]]}] do
    authorize_if always()
  end
end
```

It is possible to add extra conditions to fields and actions:

```elixir
  rbac do
    role :user do
      fields [:name, {:email, actor_attribute_equals(:field, "value")}]
      actions [{:read, accessing_from(RelatedResource, :path)}]
    end
  end
```

The conditions are added to the generated policies as well.

```elixir
field_policies do
  field_policy [:name], [{AshRbac.HasRole, [role: [:user]]}] do
    authorize_if always()
  end

  field_policy [:email], [{AshRbac.HasRole, [role: [:user], actor_attribute_equals(:field, "value")]}] do
    authorize_if always()
  end

  # it also adds a policy for all other fields like this
  field_policy [:other_fields, ...] do
    forbid_if always()
  end
end

policies do
  policy [action(:read), {hAshRbac.HasRole, [role: [:user]]}, accessing_from(RelatedResource, :path)] do
    authorize_if always()
  end
end
```
