defmodule FunLibrary.Repo.Migrations.CreateReadingProgress do
  use Ecto.Migration

  def change do
    create table(:reading_progress) do
      add :current_page, :integer
      add :recorded_at, :utc_datetime
      add :book_id, references(:books, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:reading_progress, [:book_id])
  end
end
