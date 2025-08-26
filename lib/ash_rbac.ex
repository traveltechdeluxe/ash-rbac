defmodule AshRbac do
  @role_type {:or, [:atom, :string, {:list, {:or, [:atom, :string]}}]}

  @role %Spark.Dsl.Entity{
    name: :role,
    imports: [
      Ash.Policy.Check.Builtins,
      Ash.Expr
    ],
    describe: "If the check is true, the request is forbidden, otherwise run remaining checks.",
    target: AshRbac.Role,
    args: [:role],
    links: [],
    schema: [
      role: [
        type: @role_type,
        required: true,
        doc: """
        The role this config is for
        """
      ],
      roles_field: [
        type: :atom,
        required: false,
        doc: """
        The actor roles field name
        """
      ],
      fields: [
        type:
          {:list,
           {
             :or,
             [
               :atom,
               {:tuple,
                [
                  {:or, [:atom, {:list, :atom}]},
                  {
                    :or,
                    [
                      {:list, {:custom, __MODULE__, :validate_check, []}},
                      {:custom, __MODULE__, :validate_check, []}
                    ]
                  }
                ]}
             ]
           }},
        required: false,
        doc: """
        The fields the role has access to
        """
      ],
      actions: [
        type:
          {:list,
           {
             :or,
             [
               :atom,
               {:tuple,
                [
                  {
                    :or,
                    [
                      :atom,
                      {:list, :atom}
                    ]
                  },
                  {
                    :or,
                    [
                      {:list, {:custom, __MODULE__, :validate_check, []}},
                      {:custom, __MODULE__, :validate_check, []}
                    ]
                  }
                ]}
             ]
           }},
        required: false,
        doc: """
        The actions the role has access to
        """
      ]
    ],
    examples: [
      "role :user, [:id, :name]"
    ]
  }

  @rbac_iam %Spark.Dsl.Section{
    name: :iam,
    describe: "IAM-style policy integration",
    schema: [
      permission_base: [
        type: :string,
        required: true,
        doc: "The ARN-like base identifier for this resource"
      ],
      action_to_iam_mapping: [
        type: :keyword_list,
        default: [],
        doc: "Maps Ash actions to IAM verbs (both keys and values must be atoms)"
      ],
      policy_key: [
        type: :atom,
        default: :iam_policy,
        doc: "The key in the actor map where the IAM policy document is stored"
      ],
      policy_fetcher: [
        type: {:tuple, [:atom, :atom]},
        doc:
          "MFA {module, function} to fetch policy document. Called with (actor, action, resource, record)"
      ]
    ]
  }

  @rbac %Spark.Dsl.Section{
    name: :rbac,
    describe: @moduledoc,
    examples: [
      """
      rbac do
        bypass :admin

        role :user do
          fields [:id, :name]
          actions [:create, :read, :update, :destroy]
        end
      end
      """
    ],
    schema: [
      bypass: [
        type: @role_type,
        doc: "Role that is allowed to bypass authorization"
      ],
      bypass_roles_field: [
        type: :atom,
        required: false,
        doc: "The actor roles field name for the bypass"
      ],
      public?: [
        type: :boolean,
        doc: "Allow all access",
        default: false
      ]
    ],
    entities: [
      @role
    ],
    sections: [
      @rbac_iam
    ]
  }

  defmodule Info do
    @moduledoc """
    Introspection functions for the Rbac Extension
    """
    alias Ash.Domain.Info, as: DomainInfo
    alias Spark.Dsl.Extension

    def bypass(resource) do
      Extension.get_opt(resource, [:rbac], :bypass, nil)
    end

    def bypass_roles_field(resource) do
      Extension.get_opt(resource, [:rbac], :bypass_roles_field, :roles)
    end

    def public?(resource) do
      Extension.get_opt(resource, [:rbac], :public?, false)
    end

    def roles(resource) do
      Extension.get_entities(resource, [:rbac])
    end

    def iam_permission_base(resource) do
      Extension.get_opt(resource, [:rbac, :iam], :permission_base, nil)
    end

    def iam_action_to_iam_mapping(resource) do
      Extension.get_opt(resource, [:rbac, :iam], :action_to_iam_mapping, [])
    end

    def iam_policy_key(resource) do
      Extension.get_opt(resource, [:rbac, :iam], :policy_key, :iam_policy)
    end

    def iam_policy_fetcher(resource) do
      Extension.get_opt(resource, [:rbac, :iam], :policy_fetcher, nil)
    end

    @doc """
    Gets all IAM permission bases from a domain's resources or a list of resources.

    Returns a list of permission bases for all resources that have IAM configuration.

    ## Examples

        # From a domain
        iex> AshRbac.Info.iam_permission_bases(MyApp.Domain)
        ["app:user", "app:document", "app:admin"]

        # From a list of resources
        iex> AshRbac.Info.iam_permission_bases([MyApp.User, MyApp.Document])
        ["app:user", "app:document"]

    """
    def iam_permission_bases(domain) when is_atom(domain) do
      domain
      |> DomainInfo.resources()
      |> Enum.map(&iam_permission_base/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
    end

    def iam_permission_bases(resources) when is_list(resources) do
      resources
      |> Enum.map(&iam_permission_base/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
    end

    @doc """
    Gets all IAM permission bases with app stem prefix applied.

    Similar to `iam_permission_bases/1` but applies the configured `iam_stem` prefix
    to each permission base, showing the final permission identifiers that would be
    used in policy evaluation.

    ## Examples

        # With app config: config :ash_rbac, iam_stem: "prod"
        iex> AshRbac.Info.iam_permission_bases_with_stem(MyApp.Domain)
        ["prod:app:user", "prod:app:document"]

    """
    def iam_permission_bases_with_stem(domain_or_resources) do
      stem = Application.get_env(:ash_rbac, :iam_stem)

      domain_or_resources
      |> iam_permission_bases()
      |> Enum.map(fn base ->
        case stem do
          nil -> base
          stem -> "#{stem}:#{base}"
        end
      end)
    end
  end

  @doc false
  # copied from Ash.Policy.Authorizer
  def validate_check({module, opts}) when is_atom(module) and is_list(opts) do
    {:ok, {module, opts}}
  end

  def validate_check(module) when is_atom(module) do
    validate_check({module, []})
  end

  def validate_check(other) do
    {:ok, {Ash.Policy.Check.Expression, expr: other}}
  end

  def validate_condition(conditions) when is_list(conditions) do
    {:ok,
     Enum.map(conditions, fn condition ->
       {:ok, v} = condition |> validate_check()
       v
     end)}
  end

  @doc false
  def validate_condition(condition) do
    validate_condition([condition])
  end

  use Spark.Dsl.Extension,
    transformers: [AshRbac.Policies],
    sections: [@rbac]
end
