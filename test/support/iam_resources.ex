defmodule AshRbac.IamTest.Domain do
  @moduledoc false

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshRbac.IamTest.User
    resource AshRbac.IamTest.HybridUser
    resource AshRbac.IamTest.CustomPolicyUser
    resource AshRbac.IamTest.MfaUser
  end
end

defmodule AshRbac.IamTest.User do
  @moduledoc false

  use Ash.Resource,
    domain: AshRbac.IamTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshRbac]

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
    attribute :email, :string, public?: true
  end

  actions do
    default_accept [:*]
    defaults [:create, :read, :update, :destroy]
  end

  rbac do
    role :admin do
      fields [:name]
      actions [:read]
    end

    iam do
      permission_base "app:user"
      action_to_iam_mapping create: :create, delete: :delete
    end
  end
end

defmodule AshRbac.IamTest.HybridUser do
  @moduledoc false

  use Ash.Resource,
    domain: AshRbac.IamTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshRbac]

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
    attribute :email, :string, public?: true
  end

  actions do
    default_accept [:*]
    defaults [:create, :read, :update, :destroy]
  end

  rbac do
    role :admin do
      fields [:name, :email]
      actions [:read, :update]
    end

    iam do
      permission_base "app:hybrid_user"
      action_to_iam_mapping create: :create, delete: :delete
    end
  end
end

defmodule AshRbac.IamTest.TestPolicyFetcher do
  @moduledoc false

  def get_policy(actor, _action, _resource, _record) do
    case Map.get(actor, :user_id) do
      "admin" ->
        %{
          "Statement" => [
            %{"Effect" => "Allow", "Action" => ["*"], "Resource" => ["*"]}
          ]
        }

      "user" ->
        %{
          "Statement" => [
            %{"Effect" => "Allow", "Action" => ["read"], "Resource" => ["app:mfa_user:*"]}
          ]
        }

      _ ->
        nil
    end
  end
end

defmodule AshRbac.IamTest.CustomPolicyUser do
  @moduledoc false

  use Ash.Resource,
    domain: AshRbac.IamTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshRbac]

  attributes do
    uuid_primary_key :id
  end

  rbac do
    iam do
      permission_base "app:custom_user"
      policy_key :my_custom_policy
    end
  end
end

defmodule AshRbac.IamTest.MfaUser do
  @moduledoc false

  use Ash.Resource,
    domain: AshRbac.IamTest.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshRbac]

  attributes do
    uuid_primary_key :id
  end

  rbac do
    iam do
      permission_base "app:mfa_user"
      policy_fetcher {AshRbac.IamTest.TestPolicyFetcher, :get_policy}
    end
  end
end
