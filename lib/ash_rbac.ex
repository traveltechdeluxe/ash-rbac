defmodule AshRbac do
  @role %Spark.Dsl.Entity{
    name: :role,
    describe: "If the check is true, the request is forbidden, otherwise run remaining checks.",
    target: AshRbac.Role,
    args: [:role, :fields],
    links: [],
    schema: [
      role: [
        type: :atom,
        required: true,
        doc: """
        The role this config is for
        """
      ],
      fields: [
        type: {:list, :atom},
        required: true,
        doc: """
        The fields the role has access to
        """
      ],
      actions: [
        type: {:list, :atom},
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

  @rbac %Spark.Dsl.Section{
    name: :rbac,
    describe: @moduledoc,
    examples: [
      """
      rbac do
        bypass :admin
        role :user, [:id, :name] do
          actions [:create, :read, :update, :destroy]
        end
      end
      """
    ],
    schema: [
      bypass: [
        type: :atom,
        doc: "Role that is allowed to bypass authorization"
      ],
      public?: [
        type: :boolean,
        doc: "Allow all access",
        default: false
      ]
    ],
    entities: [
      @role
    ]
  }

  defmodule Info do
    @moduledoc """
    Introspection functions for the Audit Extension
    """
    alias Spark.Dsl.Extension

    def bypass(resource) do
      Extension.get_opt(resource, [:rbac], :bypass, nil)
    end

    def public?(resource) do
      Extension.get_opt(resource, [:rbac], :public?, false)
    end

    def roles(resource) do
      Extension.get_entities(resource, [:rbac])
    end
  end

  use Spark.Dsl.Extension,
    transformers: [AshRbac.Policies],
    sections: [@rbac]
end
