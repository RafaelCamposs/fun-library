defmodule FunLibrary.Repo.Migrations.SplitBookCatalogFromReadingListEntry do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:books, [:user_id, :external_id])
    drop table(:reading_sessions)

    alter table(:books) do
      remove :user_id, :integer
      remove :status, :string
      remove :started_at, :date
      remove :finished_at, :date
      remove :author, :string
      add :authors, {:array, :string}, default: []
      modify :title, :string, null: false
      modify :isbn, :string, null: false
      modify :external_id, :string, null: false
      modify :external_source, :string, null: false
    end

    create unique_index(:books, [:isbn])

    create table(:reading_list_entries) do
      add :user_id, :integer, null: false
      add :book_id, references(:books, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "want_to"
      add :started_at, :date
      add :finished_at, :date

      timestamps(type: :utc_datetime)
    end

    create unique_index(:reading_list_entries, [:user_id, :book_id])

    create table(:reading_sessions) do
      add :reading_list_entry_id, references(:reading_list_entries, on_delete: :delete_all),
        null: false

      add :start_page, :integer, null: false
      add :end_page, :integer
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:reading_sessions, [:reading_list_entry_id])
  end
end
