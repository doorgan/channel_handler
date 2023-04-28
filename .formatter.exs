spark_locals_without_parens = [
  channel: 1,
  join: 1,
  event: 3,
  handle: 2,
  delegate: 2,
  scope: 2,
  plug: 1,
  plug: 2,
  router: 2
]

[
  import_deps: [:spark],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
  plugins: [Spark.Formatter],
  locals_without_parens: [],
  export: [
    locals_without_parens: spark_locals_without_parens
  ]
]
