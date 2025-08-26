# Used by "mix format"
spark_locals_without_parens = [
  action_to_iam_mapping: 1,
  actions: 1,
  bypass_roles_field: 1,
  bypass: 1,
  fields: 1,
  iam: 1,
  permission_base: 1,
  policy_fetcher: 1,
  policy_key: 1,
  public?: 1,
  rbac: 1,
  role: 2,
  roles_field: 1
]

[
  locals_without_parens: spark_locals_without_parens,
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:ash],
  plugins: [Spark.Formatter],
  export: [
    locals_without_parens: spark_locals_without_parens
  ]
]
