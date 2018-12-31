defmodule NewRelicEctoTest do
  use ExUnit.Case
  import Ecto.Query

  alias NewRelic.Harvest.Collector

  # Wire up our Ecto Repo
  defmodule TestRepo do
    use Ecto.Repo, otp_app: :new_relic_ecto, adapter: Ecto.Adapters.Postgres
  end

  defmodule TestItem do
    use Ecto.Schema

    schema "items" do
      field :name
    end
  end

  defmodule TestMigration do
    use Ecto.Migration

    def up do
      create table("items") do
        add :name, :string
      end
    end
  end

  @port 9999
  @config [
    database: "new_relic_ecto",
    username: "postgres",
    password: "password",
    hostname: "localhost",
    port: @port
  ]
  Application.put_env(:new_relic_ecto, :ecto_repos, [__MODULE__.TestRepo])
  Application.put_env(:new_relic_ecto, __MODULE__.TestRepo, @config)

  setup_all do
    # Instrument the Repo via Telemetry
    start_supervised({NewRelic.Ecto.Telemetry, repos: [NewRelicEctoTest.TestRepo]})

    # Initialize and start the Repo
    Ecto.Adapters.Postgres.storage_down(@config)
    :ok = Ecto.Adapters.Postgres.storage_up(@config)
    TestRepo.start_link()
    Ecto.Migrator.run(TestRepo, [{0, TestMigration}], :up, all: true)

    :ok
  end

  test "Report expected metrics" do
    restart_harvest_cycle(Collector.Metric.HarvestCycle)

    {:ok, _} = TestRepo.insert(%TestItem{name: "first"})
    {:ok, _} = TestRepo.insert(%TestItem{name: "second"})
    {:ok, _} = TestRepo.insert(%TestItem{name: "third"})

    items = TestRepo.all(from(i in TestItem))
    assert length(items) == 3

    metrics = gather_harvest(Collector.Metric.Harvester)
    assert find_metric(metrics, "Datastore/statement/Postgres/items/insert", 3)
  end

  defp gather_harvest(harvester) do
    Process.sleep(300)
    harvester.gather_harvest
  end

  defp restart_harvest_cycle(harvest_cycle) do
    GenServer.call(harvest_cycle, :restart)
  end

  defp find_metric(metrics, name, call_count) do
    Enum.find(metrics, fn
      [%{name: ^name}, [^call_count, _, _, _, _, _]] -> true
      _ -> false
    end)
  end
end
