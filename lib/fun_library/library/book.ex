defmodule FunLibrary.Library.Book do
  use Ecto.Schema
  import Ecto.Changeset
  alias FunLibrary.Reading.ReadingListEntry

  schema "books" do
    field :external_id, :string
    field :external_source, :string
    field :title, :string
    field :authors, {:array, :string}, default: []
    field :isbn, :string
    field :cover_url, :string
    field :total_pages, :integer
    field :published_year, :integer
    has_many :reading_list_entries, ReadingListEntry

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(book, attrs) do
    book
    |> cast(attrs, [
      :external_id,
      :external_source,
      :title,
      :authors,
      :isbn,
      :cover_url,
      :total_pages,
      :published_year
    ])
    |> validate_required([:external_id, :external_source, :title, :isbn])
    |> unique_constraint(:isbn)
  end
end
