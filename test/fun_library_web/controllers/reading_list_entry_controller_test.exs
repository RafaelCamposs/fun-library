defmodule FunLibraryWeb.ReadingListEntryControllerTest do
  use FunLibraryWeb.ConnCase

  import FunLibrary.LibraryFixtures
  import FunLibrary.ReadingFixtures
  alias FunLibrary.Reading.ReadingListEntry

  @book_attrs %{
    "title" => "The Hobbit",
    "isbn" => "9780261102217",
    "external_id" => "zyTCAlFPjgYC",
    "external_source" => "google_books"
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists reading list entries for the given user", %{conn: conn} do
      entry = reading_list_entry_fixture(user_id: 1)
      reading_list_entry_fixture(user_id: 2)

      conn = get(conn, ~p"/api/reading_list_entries?user_id=1")
      assert [%{"id" => id}] = json_response(conn, 200)["data"]
      assert id == entry.id
    end
  end

  describe "create" do
    test "confirms a looked-up book into the reading list, defaulting to :want_to", %{
      conn: conn
    } do
      conn = post(conn, ~p"/api/reading_list_entries", user_id: 1, book: @book_attrs)

      assert %{"id" => id, "status" => "want_to", "user_id" => 1} =
               json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/reading_list_entries/#{id}")
      assert %{"id" => ^id} = json_response(conn, 200)["data"]
    end

    test "accepts an explicit status for logging an already-finished book", %{conn: conn} do
      conn =
        post(conn, ~p"/api/reading_list_entries",
          user_id: 1,
          book: @book_attrs,
          entry: %{"status" => "read", "finished_at" => "2026-01-01"}
        )

      assert %{"status" => "read", "finished_at" => "2026-01-01"} =
               json_response(conn, 201)["data"]
    end

    test "reuses the catalog book across users, deduped by isbn", %{conn: conn} do
      book = book_fixture(isbn: @book_attrs["isbn"])

      conn = post(conn, ~p"/api/reading_list_entries", user_id: 1, book: @book_attrs)

      assert %{"book_id" => book_id} = json_response(conn, 201)["data"]
      assert book_id == book.id
    end

    test "renders conflict-style changeset error for a duplicate (user, book)", %{conn: conn} do
      post(conn, ~p"/api/reading_list_entries", user_id: 1, book: @book_attrs)
      conn = post(conn, ~p"/api/reading_list_entries", user_id: 1, book: @book_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update" do
    setup [:create_entry]

    test "renders entry when data is valid", %{
      conn: conn,
      entry: %ReadingListEntry{id: id} = entry
    } do
      conn =
        put(conn, ~p"/api/reading_list_entries/#{entry}", reading_list_entry: %{status: :reading})

      assert %{"id" => ^id, "status" => "reading"} = json_response(conn, 200)["data"]
    end
  end

  describe "delete" do
    setup [:create_entry]

    test "deletes chosen entry", %{conn: conn, entry: entry} do
      conn = delete(conn, ~p"/api/reading_list_entries/#{entry}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/reading_list_entries/#{entry}")
      end
    end
  end

  defp create_entry(_) do
    %{entry: reading_list_entry_fixture()}
  end
end
