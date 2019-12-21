defmodule NewRelic.Ecto.Telemetry do
  use GenServer

  @handler_id :new_relic_ecto

  def start_link(metrics: metrics) do
    GenServer.start_link(__MODULE__, metrics: metrics)
  end

  def init(metrics: metrics) do
    Process.flag(:trap_exit, true)

    Enum.each(metrics, fn metric ->
      :telemetry.attach(
        @handler_id,
        metric.event_name,
        &__MODULE__.handle_event/4,
        %{metric: metric}
      )
    end)

    {:ok, %{metrics: metrics}}
  end

  def terminate(_reason, _state) do
    :telemetry.detach(@handler_id)
  end

  # TODO:
  # * [x] Report DataStore metrics & aggregate
  # * [ ] Report TT segments & DT spans
  # * [x] Increment datastore_call_count, etc
  # * [x] PR `repo` into ecto metadata

  def handle_event(
        _event,
        %{query_time: duration_ns},
        %{type: :ecto_sql_query, repo: repo} = metadata,
        %{metric: _metric}
      ) do
    duration_ms = System.convert_time_unit(duration_ns, :nanosecond, :millisecond)
    duration_s = System.convert_time_unit(duration_ns, :nanosecond, :second)

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
