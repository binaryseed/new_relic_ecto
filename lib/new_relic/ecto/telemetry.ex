defmodule NewRelic.Ecto.Telemetry do
  use GenServer

  def start_link(otp_app: otp_app) do
    GenServer.start_link(__MODULE__, otp_app: otp_app)
  end

  def init(otp_app: otp_app) do
    %{handler_id: handler_id, events: events} = config = extract_config(otp_app)

    :telemetry.attach_many(
      handler_id,
      events,
      &__MODULE__.handle_event/4,
      config
    )

    Process.flag(:trap_exit, true)
    {:ok, config}
  end

  def terminate(_reason, %{handler_id: handler_id}) do
    :telemetry.detach(handler_id)
  end

  defp extract_config(otp_app) do
    ecto_repos = Application.get_env(otp_app, :ecto_repos)

    %{
      otp_app: otp_app,
      events: extract_events(otp_app, ecto_repos),
      repo_configs: extract_repo_configs(otp_app, ecto_repos),
      handler_id: {:new_relic_ecto, otp_app}
    }
  end

  defp extract_events(otp_app, ecto_repos) do
    Enum.map(ecto_repos, fn repo ->
      ecto_telemetry_prefix(otp_app, repo) ++ [:query]
    end)
  end

  defp extract_repo_configs(otp_app, ecto_repos) do
    Enum.into(ecto_repos, %{}, fn repo ->
      {repo, Application.get_env(otp_app, repo) |> Map.new()}
    end)
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
  # * [x] Report TT segments
  # * [ ] Report DT spans
  # * [x] Increment datastore_call_count, etc
  # * [x] PR `repo` into ecto metadata

  def handle_event(
        _event,
        %{query_time: duration_ns},
        %{type: :ecto_sql_query, repo: repo, query: query} = metadata,
        config
      ) do
    end_time = System.system_time(:millisecond)
    duration_ms = System.convert_time_unit(duration_ns, :nanosecond, :millisecond)
    duration_s = duration_ms / 1000
    start_time = end_time - duration_ms

    %{hostname: hostname, port: port, database: database} = config.repo_configs[repo]

    pid = inspect(self())
    id = {:ecto_sql_query, make_ref()}
    parent_id = Process.get(:nr_current_span) || :root

    with {datastore, table, operation} <- parse_ecto_metadata(metadata) do
      metric_name = "Datastore/statement/#{datastore}/#{table}/#{operation}"
      secondary_name = "#{inspect(repo)} #{hostname}:#{port}/#{database}"

      NewRelic.Transaction.Reporter.add_trace_segment(%{
        primary_name: metric_name,
        secondary_name: secondary_name,
        attributes: %{
          sql: query,
          collection: table,
          operation: operation,
          host: hostname,
          database_name: database,
          port_path_or_id: port
        },
        pid: pid,
        id: id,
        parent_id: parent_id,
        start_time: start_time,
        end_time: end_time
      })

      NewRelic.report_span(
        timestamp_ms: start_time,
        duration_s: duration_s,
        name: metric_name,
        edge: [span: id, parent: parent_id],
        category: "datastore",
        attributes: %{
          component: datastore,
          "span.kind": :client,
          "db.statement": query,
          "db.instance": database,
          "peer.address": "#{hostname}:#{port}}",
          "peer.hostname": hostname,
          "ecto.repo": inspect(repo),
          "db.table": table,
          "db.operation": operation
        }
      )

      NewRelic.report_metric(
        {:datastore, datastore, table, operation},
        duration_s: duration_s
      )

      NewRelic.incr_attributes(
        databaseCallCount: 1,
        databaseDuration: duration_s,
        datastore_call_count: 1,
        datastore_duration_ms: duration_ms,
        "datastore.#{table}.call_count": 1,
        "datastore.#{table}.duration_ms": duration_ms
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
