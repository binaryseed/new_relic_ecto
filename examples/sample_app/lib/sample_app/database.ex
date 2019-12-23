defmodule SampleApp.Database do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    config = Application.get_env(:sample_app, SampleApp.Repo)

    Ecto.Adapters.Postgres.storage_down(config)
    :ok = Ecto.Adapters.Postgres.storage_up(config)

    SampleApp.Repo.start_link()
    Ecto.Migrator.up(SampleApp.Repo, 0, SampleApp.Migration)

    {:ok, %{}}
  end
end
