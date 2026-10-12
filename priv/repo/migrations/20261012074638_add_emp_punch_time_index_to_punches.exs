defmodule Once.Repo.Migrations.AddEmpPunchTimeIndexToPunches do
  use Ecto.Migration

  def change do
    create_if_not_exists index(:biotime_punches, [:emp_code, :punch_time])
  end
end
