# Relationships

As relationships are not part of field policies it is necessary to protect them with an action policy.
This can be done by passing a custom condition to the action.

```elixir
# only allow read access if accessed from a parent
rbac do
  role :user do
    actions [
      {:read, accessing_from(Parent, :child)}
    ]
  end
end

# result
policies do
  policy [action(:read), accessing_from(Parent, :child)] do
    authorize_if {AshRbac.HasRole, [role: :user]}
  end
end
```
