[
  line_length: 150,
  import_deps: [:ecto, :ecto_sql, :phoenix, :ash, :ash_postgres],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
]
