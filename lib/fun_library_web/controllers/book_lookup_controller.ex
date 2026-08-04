defmodule FunLibraryWeb.BookLookupController do
  use FunLibraryWeb, :controller

  alias FunLibrary.BookLookup

  action_fallback FunLibraryWeb.FallbackController

  @doc """
  Looks up a book by ISBN via the external catalog source. Persists
  nothing — this is the "preview" step of adding a book to a reading list.
  """
  def create(conn, %{"isbn" => isbn}) do
    with {:ok, attrs} <- BookLookup.find_by_isbn(isbn) do
      render(conn, :show, book: attrs)
    end
  end
end
