defmodule AshRbac.Iam.Policy do
  @moduledoc """
  IAM-style policy evaluation for AshRbac.

  This module provides functions to evaluate AWS IAM-like policy documents
  for authorization decisions. It supports wildcard matching, deny precedence,
  and configurable policy sources.
  """

  @doc """
  Evaluates if the given actor is allowed to perform an action on a resource.
  """
  def allowed?(actor, action, resource, record \\ "*") do
    resource_module = resource.__struct__

    # Get IAM configuration
    permission_base = AshRbac.Info.iam_permission_base(resource_module)
    action_to_iam_mapping = AshRbac.Info.iam_action_to_iam_mapping(resource_module)
    policy_key = AshRbac.Info.iam_policy_key(resource_module)
    policy_fetcher = AshRbac.Info.iam_policy_fetcher(resource_module)

    # Get or fetch the policy document
    policy = get_policy(actor, action, resource, record, policy_key, policy_fetcher)

    # If no policy found, authorization fails
    case policy do
      nil ->
        false

      policy_doc ->
        # Apply app config prefix if configured
        final_permission_base = apply_iam_stem(permission_base)

        verb = Keyword.get(action_to_iam_mapping, action, action)
        candidate = "#{final_permission_base}:#{record_id(record)}"

        evaluate(policy_doc, candidate, verb)
    end
  end

  defp get_policy(actor, action, resource, record, policy_key, policy_fetcher) do
    case policy_fetcher do
      {module, function} ->
        # Use the provided MFA to fetch the policy
        try do
          apply(module, function, [actor, action, resource, record])
        rescue
          _ -> nil
        end

      nil ->
        # Get from actor using the configured key
        case actor do
          %{} = actor_map -> Map.get(actor_map, policy_key)
          _ -> nil
        end
    end
  end

  defp apply_iam_stem(permission_base) do
    case Application.get_env(:ash_rbac, :iam_stem) do
      nil -> permission_base
      stem -> "#{stem}:#{permission_base}"
    end
  end

  defp record_id(nil), do: "*"
  defp record_id(%{id: id}), do: id
  defp record_id(record), do: Map.get(record, :id, "*")

  defp evaluate(policy, _candidate, _verb) when is_nil(policy) do
    false
  end

  defp evaluate(%{"Statement" => stmts}, candidate, verb) when is_list(stmts) do
    stmts
    |> Enum.reduce(:neutral, fn stmt, acc ->
      case match_statement(stmt, candidate, verb) do
        :deny -> :deny
        :allow -> if acc == :neutral, do: :allow, else: acc
        _ -> acc
      end
    end)
    |> case do
      :deny -> false
      :allow -> true
      :neutral -> false
    end
  end

  defp evaluate(_, _, _), do: false

  defp match_statement(%{"Effect" => "Deny"} = stmt, cand, verb),
    do: if(match?(stmt, cand, verb), do: :deny, else: :neutral)

  defp match_statement(%{"Effect" => "Allow"} = stmt, cand, verb),
    do: if(match?(stmt, cand, verb), do: :allow, else: :neutral)

  defp match?(%{"Action" => actions, "Resource" => resources}, candidate, verb)
       when is_list(actions) and is_list(resources) do
    verb_str = to_string(verb)
    action_matches = "*" in actions or verb_str in actions
    resource_matches = Enum.any?(resources, &wildcard_match?(candidate, &1))
    action_matches and resource_matches
  end

  defp match?(_, _, _), do: false

  defp wildcard_match?(candidate, pattern) do
    # Simple wildcard matching - convert * to regex pattern
    regex_pattern =
      pattern
      |> String.replace("*", ".*")
      |> then(&("^" <> &1 <> "$"))

    Regex.match?(Regex.compile!(regex_pattern), candidate)
  end
end
