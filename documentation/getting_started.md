# Getting Started

## Installation

Add the ash_rbac dependency to your mix.exs

```elixir
defp deps do
  [
    {:ash_rbac, "~> 0.0.1"}
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
  field_policy :name do
    allow_if {AshRbac.HasRole, [role: :user]}
  end

  field_policy :email do
    allow_if {AshRbac.HasRole, [role: :user]}
  end

  # it also adds a policy for all other fields like this
  field_policy :other_fields do
    allow_if {AshRbac.HasRole, [role: []]} # empty list is always false
  end
end

policies do
  policy action(:read) do
    allow_if {AshRbac.HasRole, [role: :user]}
  end
end
```
