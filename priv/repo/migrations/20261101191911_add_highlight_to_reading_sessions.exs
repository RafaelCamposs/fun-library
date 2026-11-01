defmodule FunLibrary.Repo.Migrations.AddHighlightToReadingSessions do
  use Ecto.Migration

  def change do
    alter table(:reading_sessions) do
      add :highlight, :string
    end
  end
end
