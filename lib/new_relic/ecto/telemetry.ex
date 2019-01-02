defmodule NewRelic.Ecto.Telemetry do
  use GenServer

  def start_link(metrics: metrics) do
    GenServer.start_link(__MODULE__, metrics: metrics)
  end

  def init(metrics: metrics) do
    Enum.each(metrics, fn metric ->
      :telemetry.attach(
        "new_relic_ecto",
        metric.event_name,
        &__MODULE__.handle_event/4,
        %{metric: metric}
      )
    end)

    :ignore
  end

  # TODO:
  # * [x] Report DataStore metrics & aggregate
  # * [ ] Report TT segments & DT spans
  # * [x] Increment datastore_call_count, etc
  # * [x] PR `repo` into ecto metadata

  def handle_event(
        _event,
        duration_ns,
        %{type: :ecto_sql_query, repo: repo} = metadata,
        %{metric: _metric}
      ) do
    duration_ms = System.convert_time_unit(duration_ns, :nanoseconds, :milliseconds)
    duration_s = System.convert_time_unit(duration_ns, :nanoseconds, :seconds)

    with {datastore, table, operation} <- parse_ecto_metadata(metadata) do
      table_name = "#{inspect(repo)}:#{table}"

      NewRelic.report_metric(
        {:datastore, datastore, table_name, operation},
        duration_s: duration_s
      )

      NewRelic.incr_attributes(
        datastore_call_count: 1,
        datastore_duration_ms: duration_ms,
        "datastore.#{table_name}.call_count": 1,
        "datastore.#{table_name}.duration_ms": duration_ms
      )
    end
  end

  def handle_event(_event, _value, _metadata, _config) do
    :ignore
  end

  # TODO:
  # * [ ] support parse_metadata for other adapters

  @insert ~r/INSERT INTO "(?<table>\w+)"/
  defp parse_ecto_metadata(%{
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
