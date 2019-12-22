use Mix.Config

if File.exists?("config/secret.exs"), do: import_config("secret.exs")

config :sample_app,
  ecto_repos: [SampleApp.Repo]

config :sample_app, SampleApp.Repo,
  database: "sample_db",
  username: "postgres",
  password: "password",
  hostname: "localhost",
  port: "9999"
