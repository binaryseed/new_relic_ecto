defmodule SampleApp.Repo do
  use Ecto.Repo,
    otp_app: :sample_app,
    adapter: Ecto.Adapters.Postgres
end

defmodule SampleApp.Count do
  use Ecto.Schema

  schema "counts" do
    timestamps()
  end
end

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
    Ecto.Migrator.run(SampleApp.Repo, [{0, SampleApp.Migration}], :up, all: true)

    {:ok, %{}}
  end
end
