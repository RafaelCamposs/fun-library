defmodule FunLibrary.Repo.Migrations.CreateReadingGoals do
  use Ecto.Migration

  def change do
    create table(:reading_goals) do
      add :user_id, :integer
      add :period_type, :string
      add :period_start, :date
      add :period_end, :date
      add :target_books, :integer

      timestamps(type: :utc_datetime)
    end
  end
end
