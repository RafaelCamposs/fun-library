defmodule FunLibrary.Repo.Migrations.AddTotalPagesToReadingListEntries do
  use Ecto.Migration

  def change do
    alter table(:reading_list_entries) do
      add :total_pages, :integer
    end
  end
end
