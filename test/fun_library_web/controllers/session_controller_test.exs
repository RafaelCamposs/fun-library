defmodule FunLibraryWeb.SessionControllerTest do
  use FunLibraryWeb.ConnCase

  import FunLibrary.ReadingFixtures
  alias FunLibrary.Reading.Session

  @create_attrs %{
    "start_page" => 0,
    "started_at" => ~U[2026-07-18 18:46:00Z]
  }
  @invalid_attrs %{"start_page" => nil, "started_at" => nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all reading_sessions for a reading list entry", %{conn: conn} do
      entry = reading_list_entry_fixture()
      conn = get(conn, ~p"/api/reading_list_entries/#{entry}/reading_sessions")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create session" do
    test "renders session when data is valid", %{conn: conn} do
      entry = reading_list_entry_fixture()

      conn =
        post(conn, ~p"/api/reading_list_entries/#{entry}/reading_sessions",
          session: @create_attrs
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/reading_sessions/#{id}")

      assert %{
               "id" => ^id,
               "reading_list_entry_id" => entry_id,
               "start_page" => 0,
               "started_at" => "2026-07-18T18:46:00Z",
               "end_page" => nil,
               "ended_at" => nil
             } = json_response(conn, 200)["data"]

      assert entry_id == entry.id
    end

    test "renders errors when data is invalid", %{conn: conn} do
      entry = reading_list_entry_fixture()

      conn =
        post(conn, ~p"/api/reading_list_entries/#{entry}/reading_sessions",
          session: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders conflict when a session is already open", %{conn: conn} do
      entry = reading_list_entry_fixture()
      session_fixture(entry.id)

      conn =
        post(conn, ~p"/api/reading_list_entries/#{entry}/reading_sessions",
          session: @create_attrs
        )

      assert json_response(conn, 409)["errors"] != %{}
    end
  end

  describe "finish session" do
    setup [:create_session]

    test "renders session when data is valid", %{conn: conn, session: %Session{id: id} = session} do
      conn =
        patch(conn, ~p"/api/reading_sessions/#{session}/finish",
          session: %{"end_page" => 30, "ended_at" => ~U[2026-07-18 20:00:00Z]}
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/reading_sessions/#{id}")

      assert %{
               "id" => ^id,
               "end_page" => 30,
               "ended_at" => "2026-07-18T20:00:00Z"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, session: session} do
      conn =
        patch(conn, ~p"/api/reading_sessions/#{session}/finish",
          session: %{"end_page" => nil, "ended_at" => nil}
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete session" do
    setup [:create_session]

    test "deletes chosen session", %{conn: conn, session: session} do
      conn = delete(conn, ~p"/api/reading_sessions/#{session}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/reading_sessions/#{session}")
      end
    end
  end

  defp create_session(_) do
    entry = reading_list_entry_fixture()
    session = session_fixture(entry.id)

    %{entry: entry, session: session}
  end
end
