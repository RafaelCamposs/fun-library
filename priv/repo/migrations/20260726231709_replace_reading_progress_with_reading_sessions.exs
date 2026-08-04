defmodule FunLibrary.Repo.Migrations.ReplaceReadingProgressWithReadingSessions do
  use Ecto.Migration

  def change do
    drop table(:reading_progress)

    create table(:reading_sessions) do
      add :book_id, references(:books, on_delete: :delete_all), null: false
      add :start_page, :integer, null: false
      add :end_page, :integer
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:reading_sessions, [:book_id])
  end
end
