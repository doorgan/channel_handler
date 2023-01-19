spark_locals_without_parens = [
  channel: 1,
  event: 1,
  event: 2,
  handler: 1,
  match: 1,
  match: 2,
  plug: 1,
  plug: 2
]

[
  import_deps: [:phoenix, :spark],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
  plugins: [Spark.Formatter],
  locals_without_parens: [],
  export: [
    locals_without_parens: spark_locals_without_parens
  ]
]
