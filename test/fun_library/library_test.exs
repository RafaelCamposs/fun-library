defmodule FunLibrary.LibraryTest do
  use FunLibrary.DataCase

  alias FunLibrary.Library

  describe "books" do
    alias FunLibrary.Library.Book

    import FunLibrary.LibraryFixtures

    @invalid_attrs %{
      title: nil,
      authors: nil,
      external_id: nil,
      external_source: nil,
      isbn: nil,
      cover_url: nil,
      total_pages: nil,
      published_year: nil
    }

    test "list_books/0 returns all books" do
      book = book_fixture()
      assert Library.list_books() == [book]
    end

    test "get_book!/1 returns the book with given id" do
      book = book_fixture()
      assert Library.get_book!(book.id) == book
    end

    test "create_book/1 with valid data creates a book" do
      valid_attrs = %{
        title: "some title",
        authors: ["some author"],
        external_id: "some external_id",
        external_source: "some external_source",
        isbn: "some isbn",
        cover_url: "some cover_url",
        total_pages: 42,
        published_year: 42
      }

      assert {:ok, %Book{} = book} = Library.create_book(valid_attrs)
      assert book.title == "some title"
      assert book.authors == ["some author"]
      assert book.external_id == "some external_id"
      assert book.external_source == "some external_source"
      assert book.isbn == "some isbn"
      assert book.cover_url == "some cover_url"
      assert book.total_pages == 42
      assert book.published_year == 42
    end

    test "create_book/1 only requires title, isbn, external_id, external_source" do
      assert {:ok, %Book{} = book} =
               Library.create_book(%{
                 title: "some title",
                 isbn: "some isbn",
                 external_id: "some external_id",
                 external_source: "some external_source"
               })

      assert is_nil(book.total_pages)
      assert is_nil(book.cover_url)
      assert is_nil(book.published_year)
      assert book.authors == []
    end

    test "create_book/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Library.create_book(@invalid_attrs)
    end

    test "create_book/1 rejects a duplicate isbn" do
      book_fixture(isbn: "duplicate isbn")

      assert {:error, changeset} =
               Library.create_book(%{
                 title: "another title",
                 isbn: "duplicate isbn",
                 external_id: "another external_id",
                 external_source: "another external_source"
               })

      assert "has already been taken" in errors_on(changeset).isbn
    end

    test "update_book/2 with valid data updates the book" do
      book = book_fixture()

      update_attrs = %{
        title: "some updated title",
        authors: ["some updated author"],
        external_id: "some updated external_id",
        external_source: "some updated external_source",
        isbn: "some updated isbn",
        cover_url: "some updated cover_url",
        total_pages: 43,
        published_year: 43
      }

      assert {:ok, %Book{} = book} = Library.update_book(book, update_attrs)
      assert book.title == "some updated title"
      assert book.authors == ["some updated author"]
      assert book.external_id == "some updated external_id"
      assert book.external_source == "some updated external_source"
      assert book.isbn == "some updated isbn"
      assert book.cover_url == "some updated cover_url"
      assert book.total_pages == 43
      assert book.published_year == 43
    end

    test "update_book/2 with invalid data returns error changeset" do
      book = book_fixture()
      assert {:error, %Ecto.Changeset{}} = Library.update_book(book, @invalid_attrs)
      assert book == Library.get_book!(book.id)
    end

    test "delete_book/1 deletes the book" do
      book = book_fixture()
      assert {:ok, %Book{}} = Library.delete_book(book)
      assert_raise Ecto.NoResultsError, fn -> Library.get_book!(book.id) end
    end

    test "change_book/1 returns a book changeset" do
      book = book_fixture()
      assert %Ecto.Changeset{} = Library.change_book(book)
    end
  end

  describe "find_or_create_book/1" do
    import FunLibrary.LibraryFixtures

    test "reuses an existing book by isbn" do
      book = book_fixture()

      assert {:ok, found} =
               Library.find_or_create_book(%{
                 title: "different title",
                 isbn: book.isbn,
                 external_id: "different external_id",
                 external_source: "different external_source"
               })

      assert found.id == book.id
      assert found.title == book.title
    end

    test "creates a new book when the isbn isn't in the catalog" do
      assert {:ok, book} =
               Library.find_or_create_book(%{
                 title: "brand new",
                 isbn: "brand new isbn",
                 external_id: "external_id",
                 external_source: "external_source"
               })

      assert book.title == "brand new"
    end
  end
end
