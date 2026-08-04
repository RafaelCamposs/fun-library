defmodule FunLibrary.BookLookup do
  @moduledoc """
  Read-only lookups of book bibliographic data from external sources, keyed
  by ISBN. Returns normalized attrs; persists nothing itself — see
  `FunLibrary.Reading.add_to_reading_list/3` for the step that stores a
  looked-up book.
  """

  alias FunLibrary.BookLookup.GoogleBooksClient
  alias FunLibrary.BookLookup.OpenLibraryClient

  @isbn_format ~r/^(\d{9}[\dXx]|\d{13})$/

  @doc """
  Looks up a book by ISBN, trying Google Books first and falling back to
  Open Library if Google has no match (or is unavailable) — Open Library
  often covers regional/foreign editions Google Books doesn't index, and
  isn't subject to Google's daily quota.

  Returns `{:ok, attrs}` with normalized bibliographic data, or
  `{:error, :isbn_invalid | :not_found | :external_api_error}`.
  """
  def find_by_isbn(isbn) do
    normalized = normalize_isbn(isbn)

    if Regex.match?(@isbn_format, normalized) do
      with {:error, _reason} <- GoogleBooksClient.find_by_isbn(normalized) do
        OpenLibraryClient.find_by_isbn(normalized)
      end
    else
      {:error, :isbn_invalid}
    end
  end

  defp normalize_isbn(isbn) do
    isbn
    |> to_string()
    |> String.replace(~r/[\s-]/, "")
  end
end
