defmodule AshRbac.Policies do
  @moduledoc """
  Adds the configured policies to the resource
  """

  use Spark.Dsl.Transformer

  alias AshRbac.Fields
  alias AshRbac.Actions
  alias Ash.Policy.Check.Builtins
  alias AshRbac.Info
  alias Spark.Dsl.Transformer

  @impl true
  def transform(dsl_state) do
    bypass = Info.bypass(dsl_state)
    bypass_roles_field = Info.bypass_roles_field(dsl_state)

    {:ok,
     case Info.public?(dsl_state) do
       false ->
         dsl_state
         |> Fields.transform()
         |> Actions.transform()
         |> add_bypass(bypass, bypass_roles_field)

       true ->
         dsl_state
         |> add_allow_policy()
     end}
  end

  defp add_bypass(dsl_state, nil, _), do: dsl_state

  defp add_bypass(dsl_state, role, roles_field),
    do: dsl_state |> add_field_bypass(role, roles_field) |> add_action_bypass(role, roles_field)

  defp add_field_bypass(dsl_state, role, roles_field) do
    {:ok, check} =
      Transformer.build_entity(
        Ash.Policy.Authorizer,
        [:field_policies, :field_policy_bypass],
        :authorize_if,
        check: [Builtins.always()]
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:field_policies], :field_policy_bypass,
        fields: :*,
        condition: [{AshRbac.HasRole, [role: [{roles_field, role}]]}],
        policies: [check]
      )

    dsl_state
    |> Transformer.add_entity([:field_policies], policy, type: :prepend)
  end

  defp add_action_bypass(dsl_state, role, roles_field) do
    {:ok, check} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies, :bypass], :authorize_if,
        check: Builtins.always()
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies], :bypass,
        condition: [{AshRbac.HasRole, [role: [{roles_field, role}]]}],
        policies: [check]
      )

    dsl_state
    |> Transformer.add_entity([:policies], policy, type: :prepend)
  end

  defp add_allow_policy(dsl_state) do
    {:ok, check} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies, :policy], :authorize_if,
        check: Builtins.always()
      )

    {:ok, policy} =
      Transformer.build_entity(Ash.Policy.Authorizer, [:policies], :policy,
        condition: Builtins.always(),
        policies: [check]
      )

    dsl_state
    |> Transformer.add_entity([:policies], policy, type: :append)
  end

  @impl true
  def before?(Ash.Policy.Authorizer.Transformers.AddMissingFieldPolicies), do: true
  def before?(_), do: false

  @impl true
  def after?(Ash.Resource.Transformers.BelongsToAttribute), do: true
  def after?(_), do: false
end
