defmodule FunLibraryWeb.StatsControllerTest do
  use FunLibraryWeb.ConnCase

  import FunLibrary.LibraryFixtures
  import FunLibrary.ReadingFixtures
  alias FunLibrary.Reading

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "summary" do
    test "returns goal progress and currently-reading entries for the given user", %{conn: conn} do
      goal =
        goal_fixture(%{
          user_id: 42,
          period_start: ~D[2026-01-01],
          period_end: ~D[2026-12-31],
          target_books: 5
        })

      entry =
        reading_list_entry_fixture(%{
          user_id: 42,
          status: :reading,
          book_id: book_fixture(%{total_pages: 100}).id
        })

      session = session_fixture(entry.id, %{"start_page" => 0})

      {:ok, _} =
        Reading.finish_session(session, %{
          "end_page" => 40,
          "ended_at" => ~U[2026-07-18 20:00:00Z]
        })

      conn = get(conn, ~p"/api/stats?user_id=42")
      data = json_response(conn, 200)["data"]

      assert [%{"goal_id" => goal_id, "target_books" => 5, "books_finished" => 0}] = data["goals"]
      assert goal_id == goal.id

      assert [%{"entry_id" => entry_id, "percent_complete" => 40.0}] = data["currently_reading"]
      assert entry_id == entry.id
    end

    test "only includes goals and entries for the requested user", %{conn: conn} do
      goal_fixture(%{user_id: 1})
      reading_list_entry_fixture(%{user_id: 1, status: :reading})

      conn = get(conn, ~p"/api/stats?user_id=2")
      data = json_response(conn, 200)["data"]

      assert data["goals"] == []
      assert data["currently_reading"] == []
    end
  end

  describe "entry stats" do
    test "returns percent complete, days elapsed, and pages per day", %{conn: conn} do
      entry =
        reading_list_entry_fixture(%{
          started_at: ~D[2026-07-10],
          book_id: book_fixture(%{total_pages: 100}).id
        })

      session =
        session_fixture(entry.id, %{"start_page" => 0, "started_at" => ~U[2026-07-10 10:00:00Z]})

      {:ok, _} =
        Reading.finish_session(session, %{
          "end_page" => 20,
          "ended_at" => ~U[2026-07-10 12:00:00Z]
        })

      conn = get(conn, ~p"/api/reading_list_entries/#{entry}/stats")
      data = json_response(conn, 200)["data"]

      assert data["percent_complete"] == 20.0
      assert data["pages_per_day"] == [%{"date" => "2026-07-10", "pages_read" => 20}]
      assert is_integer(data["days_elapsed"])
    end

    test "returns 404 for an unknown entry", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, ~p"/api/reading_list_entries/999999/stats")
      end
    end
  end
end
