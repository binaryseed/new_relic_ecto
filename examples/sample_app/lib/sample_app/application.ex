defmodule SampleApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      SampleApp.Database,
      Plug.Cowboy.child_spec(scheme: :http, plug: MyRouter, options: [port: 4001]),
      {NewRelic.Ecto.Telemetry, otp_app: :sample_app}
    ]

    opts = [strategy: :one_for_one, name: SampleApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
