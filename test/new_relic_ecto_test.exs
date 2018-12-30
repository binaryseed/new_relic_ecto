defmodule NewRelicEctoTest do
  use ExUnit.Case

  defmodule TestRepo do
    use Ecto.Repo, otp_app: :new_relic_ecto, adapter: Ecto.Adapters.Postgres
  end

  defmodule TestMigration do
    use Ecto.Migration

    def up do
      create table("items") do
        add :name, :string
      end
    end
  end

  defmodule Item do
    use Ecto.Schema

    schema "items" do
      field :name
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

  test "Setup and query the DB" do
    import Ecto.Query

    Ecto.Adapters.Postgres.storage_down(@config)
    :ok = Ecto.Adapters.Postgres.storage_up(@config)
    TestRepo.start_link()
    Ecto.Migrator.run(TestRepo, [{0, TestMigration}], :up, all: true)

    {:ok, _} = TestRepo.insert(%Item{name: "first"})
    {:ok, _} = TestRepo.insert(%Item{name: "second"})
    {:ok, _} = TestRepo.insert(%Item{name: "third"})

    items = TestRepo.all(from(i in Item))

    assert length(items) == 3
  end
end
