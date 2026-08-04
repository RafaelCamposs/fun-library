defmodule FunLibraryWeb.BookJSON do
  alias FunLibrary.Library.Book

  @doc """
  Renders a list of books.
  """
  def index(%{books: books}) do
    %{data: for(book <- books, do: data(book))}
  end

  @doc """
  Renders a single book.
  """
  def show(%{book: book}) do
    %{data: data(book)}
  end

  defp data(%Book{} = book) do
    %{
      id: book.id,
      external_id: book.external_id,
      external_source: book.external_source,
      title: book.title,
      authors: book.authors,
      isbn: book.isbn,
      cover_url: book.cover_url,
      total_pages: book.total_pages,
      published_year: book.published_year
    }
  end
end
