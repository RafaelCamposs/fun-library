defmodule FunLibrary.Library do
  @moduledoc """
  The Library context — the shared, tenant-agnostic book catalog.
  """

  import Ecto.Query, warn: false
  alias FunLibrary.Repo

  alias FunLibrary.Library.Book

  @doc """
  Returns the list of books.
  """
  def list_books do
    Repo.all(Book)
  end

  @doc """
  Gets a single book.

  Raises `Ecto.NoResultsError` if the Book does not exist.
  """
  def get_book!(id), do: Repo.get!(Book, id)

  @doc """
  Gets a single book by ISBN, or `nil` if none exists.
  """
  def get_book_by_isbn(isbn), do: Repo.get_by(Book, isbn: isbn)

  @doc """
  Creates a book.
  """
  def create_book(attrs) do
    %Book{}
    |> Book.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a book.
  """
  def update_book(%Book{} = book, attrs) do
    book
    |> Book.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a book.
  """
  def delete_book(%Book{} = book) do
    Repo.delete(book)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking book changes.
  """
  def change_book(%Book{} = book, attrs \\ %{}) do
    Book.changeset(book, attrs)
  end

  @doc """
  Finds a book by ISBN, reusing the existing catalog entry if one exists.
  Creates a new `Book` from `attrs` otherwise.
  """
  def find_or_create_book(attrs) do
    isbn = Map.get(attrs, :isbn) || Map.get(attrs, "isbn")

    case isbn && get_book_by_isbn(isbn) do
      %Book{} = book -> {:ok, book}
      _ -> create_book(attrs)
    end
  end
end
