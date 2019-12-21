defmodule NewRelic.Ecto.Telemetry do
  use GenServer

  def start_link(otp_app: otp_app) do
    GenServer.start_link(__MODULE__, otp_app: otp_app)
  end

  def init(otp_app: otp_app) do
    handler_id = {:new_relic_ecto, otp_app}
    events = determine_events(otp_app)

    :telemetry.attach_many(
      handler_id,
      events,
      &__MODULE__.handle_event/4,
      %{otp_app: otp_app, events: events}
    )

    Process.flag(:trap_exit, true)
    {:ok, %{handler_id: handler_id}}
  end

  def terminate(_reason, %{handler_id: handler_id}) do
    :telemetry.detach(handler_id)
  end

  defp determine_events(otp_app) do
    Application.get_env(otp_app, :ecto_repos)
    |> Enum.map(fn repo -> ecto_telemetry_prefix(otp_app, repo) ++ [:query] end)
  end

  defp ecto_telemetry_prefix(otp_app, repo) do
    Application.get_env(otp_app, repo)
    |> Keyword.get_lazy(:telemetry_prefix, fn ->
      repo
      |> Module.split()
      |> Enum.map(&(&1 |> Macro.underscore() |> String.to_atom()))
    end)
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
        _config
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
        databaseCallCount: 1,
        datastore_call_count: 1,
        databaseDuration: duration_s,
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
