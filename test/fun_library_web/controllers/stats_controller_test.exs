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

    test "uses the entry's total_pages override instead of the book's when set", %{conn: conn} do
      entry =
        reading_list_entry_fixture(%{
          started_at: ~D[2026-07-10],
          book_id: book_fixture(%{total_pages: 100}).id
        })

      {:ok, entry} = Reading.update_entry_pages(entry, %{"total_pages" => 40})

      session =
        session_fixture(entry.id, %{"start_page" => 0, "started_at" => ~U[2026-07-10 10:00:00Z]})

      {:ok, _} =
        Reading.finish_session(session, %{
          "end_page" => 20,
          "ended_at" => ~U[2026-07-10 12:00:00Z]
        })

      conn = get(conn, ~p"/api/reading_list_entries/#{entry}/stats")
      assert json_response(conn, 200)["data"]["percent_complete"] == 50.0
    end
  end

  describe "streak" do
    test "counts consecutive days ending today", %{conn: conn} do
      entry = reading_list_entry_fixture(%{user_id: 43})

      read_on(entry.id, Date.utc_today())
      read_on(entry.id, Date.add(Date.utc_today(), -1))
      read_on(entry.id, Date.add(Date.utc_today(), -2))

      conn = get(conn, ~p"/api/stats/43/streak")
      assert json_response(conn, 200)["data"] == %{"days" => 3}
    end

    test "still counts yesterday's streak when today has no session yet", %{conn: conn} do
      entry = reading_list_entry_fixture(%{user_id: 44})

      read_on(entry.id, Date.add(Date.utc_today(), -1))
      read_on(entry.id, Date.add(Date.utc_today(), -2))

      conn = get(conn, ~p"/api/stats/44/streak")
      assert json_response(conn, 200)["data"] == %{"days" => 2}
    end

    test "breaks the streak on a gap day", %{conn: conn} do
      entry = reading_list_entry_fixture(%{user_id: 45})

      read_on(entry.id, Date.utc_today())
      read_on(entry.id, Date.add(Date.utc_today(), -2))

      conn = get(conn, ~p"/api/stats/45/streak")
      assert json_response(conn, 200)["data"] == %{"days" => 1}
    end

    test "returns 0 when the user has no finished sessions", %{conn: conn} do
      conn = get(conn, ~p"/api/stats/46/streak")
      assert json_response(conn, 200)["data"] == %{"days" => 0}
    end

    test "ignores sessions where no pages were actually read", %{conn: conn} do
      entry = reading_list_entry_fixture(%{user_id: 47})

      session =
        session_fixture(entry.id, %{
          "start_page" => 10,
          "started_at" => DateTime.new!(Date.utc_today(), ~T[10:00:00])
        })

      {:ok, _} =
        Reading.finish_session(session, %{
          "end_page" => 10,
          "ended_at" => DateTime.new!(Date.utc_today(), ~T[11:00:00])
        })

      conn = get(conn, ~p"/api/stats/47/streak")
      assert json_response(conn, 200)["data"] == %{"days" => 0}
    end
  end

  defp read_on(entry_id, date) do
    session =
      session_fixture(entry_id, %{
        "start_page" => 0,
        "started_at" => DateTime.new!(date, ~T[10:00:00])
      })

    {:ok, _} =
      Reading.finish_session(session, %{
        "end_page" => 10,
        "ended_at" => DateTime.new!(date, ~T[11:00:00])
      })
  end
end
