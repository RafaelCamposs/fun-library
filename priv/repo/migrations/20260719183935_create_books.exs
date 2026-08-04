defmodule FunLibrary.Repo.Migrations.CreateBooks do
  use Ecto.Migration

  def change do
    create table(:books) do
      add :user_id, :integer
      add :external_id, :string
      add :external_source, :string
      add :title, :string
      add :author, :string
      add :isbn, :string
      add :cover_url, :string
      add :total_pages, :integer
      add :published_year, :integer
      add :status, :string
      add :started_at, :date
      add :finished_at, :date

      timestamps(type: :utc_datetime)
    end

    create unique_index(:books, [:user_id, :external_id])
  end
end
