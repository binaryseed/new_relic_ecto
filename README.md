# New Relic Ecto

[![Hex.pm Version](https://img.shields.io/hexpm/v/new_relic_ecto.svg)](https://hex.pm/packages/new_relic_ecto)


### Instrumentation

To instrument your Ecto Repos, start a child process in your `Application` and configure it with the name of your `otp_app`.

```elixir
defmodule MyApp do
  use Application

  def start(_type, _args) do
    children = [
      # ...
      {NewRelicEcto, otp_app: :my_app}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

### Development

Start up the database locally to run the tests:

```
docker-compose up
```
