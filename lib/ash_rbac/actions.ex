defmodule AshRbac.Actions do
  use Spark.Dsl.Transformer

  alias AshRbac.Info
  alias Ash.Policy.Check.Builtins
  alias AshRbac.Info
  alias Spark.Dsl.Transformer

  @impl true
  def transform(dsl_state) do
    action_settings =
      Info.roles(dsl_state)
      |> transform_options()

    dsl_state
    |> add_action_policies(action_settings)
  end

  defp add_action_policies(dsl_state, action_settings) when action_settings == %{}, do: dsl_state

  defp add_action_policies(dsl_state, action_settings) do
    action_settings
    |> Enum.reduce(dsl_state, fn
      {action, roles}, dsl_state ->
        add_role_action_policies(
          dsl_state,
          action,
          roles
        )
    end)
  end

  defp add_role_action_policies(dsl_state, {action, custom_condition}, roles) do
    {:ok, check} =
      Transformer.build_entity(
        Ash.Policy.Authorizer,
        [:policies, :policy],
        :authorize_if,
        check: Builtins.always()
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies], :policy,
        condition: [
          Builtins.action(action),
          {AshRbac.HasRole, [role: roles]} | List.wrap(custom_condition)
        ],
        policies: [check]
      )

    dsl_state
    |> Transformer.add_entity([:policies], policy, type: :append)
  end

  defp add_role_action_policies(dsl_state, action, roles) do
    {:ok, check} =
      Transformer.build_entity(
        Ash.Policy.Authorizer,
        [:policies, :policy],
        :authorize_if,
        check: Builtins.always()
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies], :policy,
        condition: [Builtins.action(action), {AshRbac.HasRole, [role: roles]}],
        policies: [check]
      )

    dsl_state
    |> Transformer.add_entity([:policies], policy, type: :append)
  end

  defp transform_options(roles) do
    roles
    |> Enum.reduce(%{}, fn %{actions: actions} = role, acc ->
      actions
      |> List.wrap()
      |> Enum.reduce(acc, fn action, acc ->
        Map.update(acc, action, [create_role(role)], fn roles ->
          [create_role(role) | roles]
        end)
      end)
    end)
  end

  defp create_role(%{role: role, roles_field: nil}), do: role
  defp create_role(%{role: role, roles_field: roles_field}), do: {roles_field, role}
end
