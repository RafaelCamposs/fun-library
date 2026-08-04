defmodule FunLibrary.LibraryFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FunLibrary.Library` context.
  """

  @doc """
  Generate a book.
  """
  def book_fixture(attrs \\ %{}) do
    {:ok, book} =
      attrs
      |> Enum.into(%{
        authors: ["some author"],
        cover_url: "some cover_url",
        external_id: "some external_id",
        external_source: "some external_source",
        isbn: "some isbn #{System.unique_integer()}",
        published_year: 42,
        title: "some title",
        total_pages: 42
      })
      |> FunLibrary.Library.create_book()

    book
  end
end
