defmodule FunLibrary.Reading.Goal do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reading_goals" do
    field :user_id, :integer
    field :period_type, Ecto.Enum, values: [:annual, :monthly]
    field :period_start, :date
    field :period_end, :date
    field :target_books, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [:user_id, :period_type, :period_start, :period_end, :target_books])
    |> validate_required([:user_id, :period_type, :period_start, :period_end, :target_books])
  end
end
