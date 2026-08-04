defmodule FunLibraryWeb.BookControllerTest do
  use FunLibraryWeb.ConnCase

  import FunLibrary.LibraryFixtures
  alias FunLibrary.Library.Book

  @create_attrs %{
    title: "some title",
    authors: ["some author"],
    external_id: "some external_id",
    external_source: "some external_source",
    isbn: "some isbn",
    cover_url: "some cover_url",
    total_pages: 42,
    published_year: 42
  }
  @update_attrs %{
    title: "some updated title",
    authors: ["some updated author"],
    external_id: "some updated external_id",
    external_source: "some updated external_source",
    isbn: "some updated isbn",
    cover_url: "some updated cover_url",
    total_pages: 43,
    published_year: 43
  }
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

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all books", %{conn: conn} do
      conn = get(conn, ~p"/api/books")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create book" do
    test "renders book when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/books", book: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/books/#{id}")

      assert %{
               "id" => ^id,
               "authors" => ["some author"],
               "cover_url" => "some cover_url",
               "external_id" => "some external_id",
               "external_source" => "some external_source",
               "isbn" => "some isbn",
               "published_year" => 42,
               "title" => "some title",
               "total_pages" => 42
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/books", book: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update book" do
    setup [:create_book]

    test "renders book when data is valid", %{conn: conn, book: %Book{id: id} = book} do
      conn = put(conn, ~p"/api/books/#{book}", book: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/books/#{id}")

      assert %{
               "id" => ^id,
               "authors" => ["some updated author"],
               "cover_url" => "some updated cover_url",
               "external_id" => "some updated external_id",
               "external_source" => "some updated external_source",
               "isbn" => "some updated isbn",
               "published_year" => 43,
               "title" => "some updated title",
               "total_pages" => 43
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, book: book} do
      conn = put(conn, ~p"/api/books/#{book}", book: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete book" do
    setup [:create_book]

    test "deletes chosen book", %{conn: conn, book: book} do
      conn = delete(conn, ~p"/api/books/#{book}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/books/#{book}")
      end
    end
  end

  defp create_book(_) do
    book = book_fixture()

    %{book: book}
  end
end
