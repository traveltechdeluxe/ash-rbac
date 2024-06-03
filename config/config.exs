import Config

config :logger, level: :error

config :ash, disable_async?: true

config :ash, :policies,
  log_policy_breakdowns: :debug,
  log_successful_policy_breakdowns: :debug

if Mix.env() == :dev do
  config :git_hooks,
    auto_install: true,
    verbose: true,
    branches: [
      whitelist: [".*"]
    ],
    hooks: [
      pre_push: [
        verbose: false,
        tasks: [
          {:cmd, "mix credo --strict --all"},
          {:cmd, "mix format --check-formatted"},
          {:cmd, "mix test --color"},
          {:cmd, "echo 'success!'"}
        ]
      ]
    ]
end

if Mix.env() == :test do
  config :ash_rbac, ash_domains: [AshRbacTest.Domain]
end
