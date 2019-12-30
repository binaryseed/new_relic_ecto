defmodule EctoExample.Database do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    config = Application.get_env(:ecto_example, EctoExample.Repo)

    Ecto.Adapters.Postgres.storage_down(config)
    :ok = Ecto.Adapters.Postgres.storage_up(config)

    EctoExample.Repo.start_link()
    Ecto.Migrator.up(EctoExample.Repo, 0, EctoExample.Migration)

    {:ok, %{}}
  end
end
