# IAM Integration

AshRbac provides IAM-style policy integration that allows you to use AWS IAM-like policy documents for authorization. This system is particularly useful when you need fine-grained, dynamic access control based on JSON policy documents.

## Basic Setup

To enable IAM authorization on a resource, add an `iam` section to your `rbac` block:

```elixir
defmodule MyApp.User do
  use Ash.Resource,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshRbac]

  rbac do
    iam do
      permission_base "app:user"
    end
  end
end
```

## Policy Document Structure

IAM policies follow a JSON structure similar to AWS IAM policies:

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["create", "read"],
      "Resource": ["app:user:*"]
    },
    {
      "Effect": "Deny", 
      "Action": ["delete"],
      "Resource": ["app:user:123"]
    }
  ]
}
```

The policy document should be stored on the actor (typically a user struct) in a field called `:iam_policy` by default.

## Configuration Options

### permission_base

The `permission_base` defines the ARN-like base identifier for your resource:

```elixir
iam do
  permission_base "app:user"
end
```

This creates resource identifiers like `app:user:*` or `app:user:123` for specific records.

### action_to_iam_mapping

Map Ash actions to IAM verbs when they don't match exactly:

```elixir
iam do
  permission_base "app:user"
  action_to_iam_mapping destroy: :delete, show: :read
end
```

Without this mapping, Ash actions are used directly as IAM verbs.

### policy_key

Specify where the policy document is stored on the actor:

```elixir
iam do
  permission_base "app:user"
  policy_key :custom_policy
end
```

The default is `:iam_policy`.

### policy_fetcher

Use a custom function to fetch the policy document instead of reading it from the actor:

```elixir
iam do
  permission_base "app:user"
  policy_fetcher {MyApp.PolicyService, :get_policy}
end
```

The function will be called with `(actor, action, resource, record)` and should return a policy document or `nil`.

## Application Configuration

### IAM Stem Prefix

You can configure a global prefix for all IAM resources:

```elixir
# config/config.exs
config :ash_rbac, iam_stem: "my_app"
```

This transforms `"app:user"` into `"my_app:app:user"` for all policy evaluations.

## Policy Evaluation

IAM policies are evaluated with the following logic:

1. Explicit `Deny` statements take precedence over `Allow` statements
2. At least one `Allow` statement must match for access to be granted
3. Wildcard matching is supported in both actions and resources
4. If no policy document is found, access is denied

### Wildcard Support

Both actions and resources support wildcard matching:

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["*"],
      "Resource": ["app:user:*"]
    }
  ]
}
```

## Complete Example

```elixir
defmodule MyApp.Document do
  use Ash.Resource,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshRbac]

  attributes do
    uuid_primary_key :id
    attribute :title, :string
    attribute :content, :string
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  rbac do
    iam do
      permission_base "app:document"
      action_to_iam_mapping destroy: :delete
      policy_key :document_policy
    end
  end
end

# Usage with an actor
actor = %{
  document_policy: %{
    "Statement" => [
      %{
        "Effect" => "Allow",
        "Action" => ["read", "update"],
        "Resource" => ["app:document:*"]
      },
      %{
        "Effect" => "Deny",
        "Action" => ["delete"],
        "Resource" => ["app:document:sensitive-doc-123"]
      }
    ]
  }
}

# This actor can read and update any document, but cannot delete the sensitive document
```

## Integration with Roles

IAM policies work independently of role-based permissions defined in the same resource. The IAM system only evaluates IAM policies and does not consider role memberships.
