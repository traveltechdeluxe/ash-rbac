# Used by "mix format"
spark_locals_without_parens = [
  actions: 1,
  fields: 1,
  rbac: 1,
  public?: 1,
  bypass: 1,
  bypass_roles_field: 1,
  roles_field: 1,
  role: 2
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
