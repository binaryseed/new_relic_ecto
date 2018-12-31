defmodule NewRelic.Ecto.Telemetry do
  @doc "Attach the Telemetry handler for Ecto"
  def attach(repo: repo) do
    Telemetry.attach(
      "new_relic_ecto",
      telemetry_prefix(repo) ++ [:query],
      __MODULE__,
      :handle_event,
      %{}
    )
  end

  # TODO:
  # * [x] Report DataStore metrics & aggregate
  # * [ ] Report TT segments & DT spans
  # * [x] Increment datastore_call_count, etc

  def handle_event(_event, duration_ns, metadata, _config) do
    duration_ms = System.convert_time_unit(duration_ns, :nanoseconds, :milliseconds)
    duration_s = System.convert_time_unit(duration_ns, :nanoseconds, :seconds)

    with {datastore, table, operation} <- parse_metadata(metadata) do
      NewRelic.report_metric(
        {:datastore, datastore, table, operation},
        duration_s: duration_s
      )

      NewRelic.incr_attributes(
        datastore_call_count: 1,
        datastore_duration_ms: duration_ms,
        "datastore.#{table}.call_count": 1,
        "datastore.#{table}.duration_ms": duration_ms
      )
    end
  end

  defp telemetry_prefix(repo) do
    repo
    |> Module.split()
    |> Enum.map(&(&1 |> Macro.underscore() |> String.to_atom()))
  end

  # TODO:
  # * [ ] support parse_metadata for other adapters

  @insert ~r/INSERT INTO "(?<table>\w+)"/
  defp parse_metadata(%{
         source: table,
         query: query,
         result: {:ok, %{__struct__: Postgrex.Result, command: operation}}
       }) do
    table =
      case {table, operation} do
        {nil, :insert} -> Regex.named_captures(@insert, query)["table"]
        {nil, _} -> "other"
        {table, _} -> table
      end

    {"Postgres", table, operation}
  end
end
