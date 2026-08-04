defmodule FunLibraryWeb.BookLookupControllerTest do
  use FunLibraryWeb.ConnCase

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "create" do
    test "renders a 422 for a malformed isbn", %{conn: conn} do
      conn = post(conn, ~p"/api/book_lookups", isbn: "not-an-isbn")
      assert json_response(conn, 422)["errors"] != %{}
    end
  end
end
