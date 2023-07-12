import Config

config :logger, level: :error

config :ash, disable_async?: true

config :ash, :use_all_identities_in_manage_relationship?, false

config :ash, :policies,
  show_policy_breakdowns?: true,
  log_policy_breakdowns: :debug,
  log_successful_policy_breakdowns: :debug
