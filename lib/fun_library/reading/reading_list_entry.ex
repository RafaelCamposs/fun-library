defmodule FunLibrary.Reading.ReadingListEntry do
  use Ecto.Schema
  import Ecto.Changeset
  alias FunLibrary.Library.Book
  alias FunLibrary.Reading.Session

  schema "reading_list_entries" do
    field :user_id, :integer
    field :status, Ecto.Enum, values: [:want_to, :reading, :read, :stopped, :unfinished]
    field :started_at, :date
    field :finished_at, :date
    field :total_pages, :integer
    belongs_to :book, Book
    has_many :sessions, Session

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:user_id, :book_id, :status, :started_at, :finished_at, :total_pages])
    |> validate_required([:user_id, :book_id, :status])
    |> foreign_key_constraint(:book_id)
    |> unique_constraint([:user_id, :book_id])
  end

  @doc false
  def pages_changeset(entry, attrs) do
    entry
    |> cast(attrs, [:total_pages])
    |> validate_number(:total_pages, greater_than: 0)
  end
end
