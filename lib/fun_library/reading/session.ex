defmodule FunLibrary.Reading.Session do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reading_sessions" do
    field :reading_list_entry_id, :id
    field :start_page, :integer
    field :end_page, :integer
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def start_changeset(session, attrs) do
    session
    |> cast(attrs, [:reading_list_entry_id, :start_page, :started_at])
    |> validate_required([:reading_list_entry_id, :start_page, :started_at])
    |> validate_number(:start_page, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:reading_list_entry_id)
  end

  @doc false
  def finish_changeset(session, attrs) do
    session
    |> cast(attrs, [:end_page, :ended_at])
    |> validate_required([:end_page, :ended_at])
    |> validate_number(:end_page, greater_than_or_equal_to: 0)
    |> validate_end_page()
  end

  defp validate_end_page(changeset) do
    start_page = get_field(changeset, :start_page)
    end_page = get_field(changeset, :end_page)

    if start_page && end_page && end_page < start_page do
      add_error(changeset, :end_page, "must be greater than or equal to start_page")
    else
      changeset
    end
  end
end
