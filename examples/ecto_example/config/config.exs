use Mix.Config

if File.exists?("config/secret.exs"), do: import_config("secret.exs")

config :ecto_example,
  http_port: 4001,
  ecto_repos: [EctoExample.Repo]

config :ecto_example, EctoExample.Repo,
  database: "example_db",
  username: "postgres",
  password: "password",
  hostname: "localhost",
  port: 9999
