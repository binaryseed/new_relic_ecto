defmodule SampleApp.Migration do
  use Ecto.Migration

  def up do
    create table("counts") do
      timestamps()
    end
  end
end
