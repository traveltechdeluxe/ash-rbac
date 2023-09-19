# AshRbac

A small extension that allows for easier application of policies

```elixir
rbac do
  role :user do
    fields [:fields, :user, :can, :see]
    actions [:actions, :user, :can :use]
  end
end
```

## Installation

The package can be installed by adding `ash_rbac` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_rbac, "~> 0.4.0"},
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ash_rbac>.
