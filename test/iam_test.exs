defmodule AshRbac.IamTest do
  use ExUnit.Case, async: true

  require AshRbac.IamTest.Domain
  alias AshRbac.Iam.Policy
  alias AshRbac.Info
  alias AshRbac.IamTest.{CustomPolicyUser, HybridUser, MfaUser, User}

  test "IAM allows based on policy" do
    actor = %{
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Allow", "Action" => ["create"], "Resource" => ["app:user:*"]}
        ]
      }
    }

    assert Policy.allowed?(actor, :create, %User{}, nil)
    refute Policy.allowed?(actor, :delete, %User{}, nil)
  end

  test "IAM denies explicitly" do
    actor = %{
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Deny", "Action" => ["delete"], "Resource" => ["app:user:*"]}
        ]
      }
    }

    refute Policy.allowed?(actor, :delete, %User{}, nil)
  end

  test "IAM and role permissions work together without vulnerability" do
    # Actor with both IAM policy and role permissions
    actor_with_iam_and_role = %{
      roles: [:admin],
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Allow", "Action" => ["create"], "Resource" => ["app:user:*"]}
        ]
      }
    }

    # Actor with only role permissions
    actor_with_role_only = %{roles: [:admin]}

    # Actor with only IAM permissions
    actor_with_iam_only = %{
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Allow", "Action" => ["create"], "Resource" => ["app:user:*"]}
        ]
      }
    }

    # Actor with no permissions
    actor_with_no_permissions = %{}

    # Test that IAM policy works independently of role permissions
    assert Policy.allowed?(actor_with_iam_and_role, :create, %User{}, nil)
    assert Policy.allowed?(actor_with_iam_only, :create, %User{}, nil)
    refute Policy.allowed?(actor_with_role_only, :create, %User{}, nil)
    refute Policy.allowed?(actor_with_no_permissions, :create, %User{}, nil)

    # Test that role permissions don't interfere with IAM denials
    actor_with_iam_deny = %{
      roles: [:admin],
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Deny", "Action" => ["create"], "Resource" => ["app:user:*"]}
        ]
      }
    }

    refute Policy.allowed?(actor_with_iam_deny, :create, %User{}, nil)

    # Test that IAM permissions don't interfere with actions not mapped in action_map
    # The :read action is not in the action_map, so IAM should not grant access to it
    refute Policy.allowed?(actor_with_iam_only, :read, %User{}, nil)
    refute Policy.allowed?(actor_with_iam_and_role, :read, %User{}, nil)
  end

  test "IAM policy evaluation with mixed configuration" do
    # Test that IAM policy works correctly when both role and IAM configurations exist
    # This validates that the policy functions correctly extract IAM configuration
    # even when roles are also defined in the same resource

    # Actor with IAM create permission
    iam_actor = %{
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Allow", "Action" => ["create"], "Resource" => ["app:hybrid_user:*"]}
        ]
      }
    }

    # Actor with IAM deny permission
    iam_deny_actor = %{
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Deny", "Action" => ["delete"], "Resource" => ["app:hybrid_user:*"]}
        ]
      }
    }

    # Test that IAM policy extraction works with HybridUser (which has both role and IAM config)
    assert Policy.allowed?(iam_actor, :create, %HybridUser{}, nil)
    refute Policy.allowed?(iam_deny_actor, :delete, %HybridUser{}, nil)

    # Test that actions not in action_map default to action name
    refute Policy.allowed?(iam_actor, :read, %HybridUser{}, nil)

    # Test that action_map mapping works correctly
    iam_delete_actor = %{
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Allow", "Action" => ["delete"], "Resource" => ["app:hybrid_user:*"]}
        ]
      }
    }

    assert Policy.allowed?(iam_delete_actor, :delete, %HybridUser{}, nil)

    # Verify the Info functions work correctly
    assert Info.iam_permission_base(HybridUser) == "app:hybrid_user"
    assert Info.iam_action_to_iam_mapping(HybridUser) == [create: :create, delete: :delete]
  end

  test "configurable policy key" do
    # Actor with policy in custom key
    actor_custom_key = %{
      my_custom_policy: %{
        "Statement" => [
          %{"Effect" => "Allow", "Action" => ["create"], "Resource" => ["app:custom_user:*"]}
        ]
      }
    }

    # Actor with policy in default key (should not work)
    actor_default_key = %{
      iam_policy: %{
        "Statement" => [
          %{"Effect" => "Allow", "Action" => ["create"], "Resource" => ["app:custom_user:*"]}
        ]
      }
    }

    assert Policy.allowed?(actor_custom_key, :create, %CustomPolicyUser{}, nil)
    refute Policy.allowed?(actor_default_key, :create, %CustomPolicyUser{}, nil)

    # Verify info function
    assert Info.iam_policy_key(CustomPolicyUser) == :my_custom_policy
  end

  test "MFA policy fetcher" do
    # Test admin actor
    admin_actor = %{user_id: "admin"}
    assert Policy.allowed?(admin_actor, :create, %MfaUser{}, nil)
    assert Policy.allowed?(admin_actor, :read, %MfaUser{}, nil)

    # Test regular user actor
    user_actor = %{user_id: "user"}
    refute Policy.allowed?(user_actor, :create, %MfaUser{}, nil)
    assert Policy.allowed?(user_actor, :read, %MfaUser{}, nil)

    # Test unknown actor
    unknown_actor = %{user_id: "unknown"}
    refute Policy.allowed?(unknown_actor, :create, %MfaUser{}, nil)
    refute Policy.allowed?(unknown_actor, :read, %MfaUser{}, nil)
  end

  test "graceful handling of missing policy" do
    # Actor with no policy at all
    actor_no_policy = %{some_other_field: "value"}

    # Actor with nil policy
    actor_nil_policy = %{iam_policy: nil}

    # Actor with empty policy
    actor_empty_policy = %{iam_policy: %{}}

    # All should fail gracefully (return false, not error)
    refute Policy.allowed?(actor_no_policy, :create, %User{}, nil)
    refute Policy.allowed?(actor_nil_policy, :create, %User{}, nil)
    refute Policy.allowed?(actor_empty_policy, :create, %User{}, nil)
  end

  test "app config iam_stem prefix" do
    # Set the application config
    original_stem = Application.get_env(:ash_rbac, :iam_stem)
    Application.put_env(:ash_rbac, :iam_stem, "my_app")

    try do
      # Actor with policy that should match the prefixed resource
      actor = %{
        iam_policy: %{
          "Statement" => [
            %{"Effect" => "Allow", "Action" => ["create"], "Resource" => ["my_app:app:user:*"]}
          ]
        }
      }

      # This should now work because the prefix is applied
      assert Policy.allowed?(actor, :create, %User{}, nil)

      # Actor with old non-prefixed resource should not work
      actor_old = %{
        iam_policy: %{
          "Statement" => [
            %{"Effect" => "Allow", "Action" => ["create"], "Resource" => ["app:user:*"]}
          ]
        }
      }

      refute Policy.allowed?(actor_old, :create, %User{}, nil)
    after
      # Restore original config
      if original_stem do
        Application.put_env(:ash_rbac, :iam_stem, original_stem)
      else
        Application.delete_env(:ash_rbac, :iam_stem)
      end
    end
  end
end
