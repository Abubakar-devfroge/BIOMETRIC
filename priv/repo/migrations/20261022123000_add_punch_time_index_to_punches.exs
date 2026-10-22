defmodule Once.Repo.Migrations.AddPunchTimeIndexToPunches do
  use Ecto.Migration

  def change do
    create_if_not_exists index(:biotime_punches, [:punch_time])
  end
end
