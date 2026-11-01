defmodule FunLibraryWeb.StatsControllerTest do
  use FunLibraryWeb.ConnCase

  import FunLibrary.LibraryFixtures
  import FunLibrary.ReadingFixtures
  alias FunLibrary.{Reading, Stats}

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

  describe "entry stats reading span" do
    test "spans start date to finish date for a read book", %{conn: conn} do
      entry = reading_list_entry_fixture(%{book_id: book_fixture(%{total_pages: 30}).id})

      read_pages_on(entry.id, ~D[2026-07-10], 0, 10)
      read_pages_on(entry.id, ~D[2026-07-12], 10, 30)

      data = entry_stats(conn, entry)

      assert data["reading_span"] == %{"start_date" => "2026-07-10", "end_date" => "2026-07-12"}

      assert data["pages_per_day"] == [
               %{"date" => "2026-07-10", "pages_read" => 10},
               %{"date" => "2026-07-12", "pages_read" => 20}
             ]
    end

    test "ends on the app's day when the book is finished late in the evening", %{conn: conn} do
      entry = reading_list_entry_fixture(%{book_id: book_fixture(%{total_pages: 30}).id})

      # 22:30 at UTC-3 on Jul 10 is already Jul 11 in UTC.
      session =
        session_fixture(entry.id, %{"start_page" => 0, "started_at" => ~U[2026-07-11 00:00:00Z]})

      {:ok, _} =
        Reading.finish_session(session, %{
          "end_page" => 30,
          "ended_at" => ~U[2026-07-11 01:30:00Z]
        })

      data = entry_stats(conn, entry)

      assert data["reading_span"] == %{"start_date" => "2026-07-10", "end_date" => "2026-07-10"}
      assert data["pages_per_day"] == [%{"date" => "2026-07-10", "pages_read" => 30}]
    end

    test "leaves out sessions after a hand-edited finish date", %{conn: conn} do
      entry = reading_list_entry_fixture(%{book_id: book_fixture(%{total_pages: 30}).id})

      read_pages_on(entry.id, ~D[2026-07-10], 0, 10)
      read_pages_on(entry.id, ~D[2026-07-12], 10, 30)

      {:ok, entry} =
        Reading.update_reading_list_entry(entry, %{finished_at: ~D[2026-07-11]})

      data = entry_stats(conn, entry)

      assert data["reading_span"] == %{"start_date" => "2026-07-10", "end_date" => "2026-07-11"}
      assert data["pages_per_day"] == [%{"date" => "2026-07-10", "pages_read" => 10}]
    end

    test "ends today for a book being read", %{conn: conn} do
      entry = reading_list_entry_fixture(%{book_id: book_fixture(%{total_pages: 100}).id})

      read_pages_on(entry.id, ~D[2026-07-10], 0, 10)

      data = entry_stats(conn, entry)

      assert data["reading_span"] == %{
               "start_date" => "2026-07-10",
               "end_date" => Date.to_iso8601(Stats.today())
             }
    end

    test "ends on the last reading day for a stopped book", %{conn: conn} do
      entry = reading_list_entry_fixture(%{book_id: book_fixture(%{total_pages: 100}).id})

      read_pages_on(entry.id, ~D[2026-07-10], 0, 10)
      read_pages_on(entry.id, ~D[2026-07-14], 10, 25)
      # A session that advanced no pages is not a reading day.
      read_pages_on(entry.id, ~D[2026-07-20], 25, 25)

      {:ok, entry} = Reading.update_reading_list_entry(entry, %{status: :stopped})

      assert entry_stats(conn, entry)["reading_span"] == %{
               "start_date" => "2026-07-10",
               "end_date" => "2026-07-14"
             }
    end

    test "is just the start date for an unfinished book with no reading days", %{conn: conn} do
      entry = reading_list_entry_fixture(%{status: :unfinished, started_at: ~D[2026-07-10]})

      assert entry_stats(conn, entry)["reading_span"] == %{
               "start_date" => "2026-07-10",
               "end_date" => "2026-07-10"
             }
    end

    test "is null with no pages per day when the entry has no start date", %{conn: conn} do
      entry = reading_list_entry_fixture(%{status: :read, finished_at: ~D[2026-07-10]})

      data = entry_stats(conn, entry)

      assert data["reading_span"] == nil
      assert data["pages_per_day"] == []
    end
  end

  describe "streak" do
    test "counts consecutive days ending today", %{conn: conn} do
      entry = reading_list_entry_fixture(%{user_id: 43})

      read_on(entry.id, Stats.today())
      read_on(entry.id, Date.add(Stats.today(), -1))
      read_on(entry.id, Date.add(Stats.today(), -2))

      conn = get(conn, ~p"/api/stats/43/streak")
      assert json_response(conn, 200)["data"] == %{"current" => 3, "record" => 3}
    end

    test "still counts yesterday's streak when today has no session yet", %{conn: conn} do
      entry = reading_list_entry_fixture(%{user_id: 44})

      read_on(entry.id, Date.add(Stats.today(), -1))
      read_on(entry.id, Date.add(Stats.today(), -2))

      conn = get(conn, ~p"/api/stats/44/streak")
      assert json_response(conn, 200)["data"] == %{"current" => 2, "record" => 2}
    end

    test "breaks the streak on a gap day", %{conn: conn} do
      entry = reading_list_entry_fixture(%{user_id: 45})

      read_on(entry.id, Stats.today())
      read_on(entry.id, Date.add(Stats.today(), -2))

      conn = get(conn, ~p"/api/stats/45/streak")
      assert json_response(conn, 200)["data"] == %{"current" => 1, "record" => 1}
    end

    test "returns 0 when the user has no finished sessions", %{conn: conn} do
      conn = get(conn, ~p"/api/stats/46/streak")
      assert json_response(conn, 200)["data"] == %{"current" => 0, "record" => 0}
    end

    test "ignores sessions where no pages were actually read", %{conn: conn} do
      entry = reading_list_entry_fixture(%{user_id: 47})

      session =
        session_fixture(entry.id, %{
          "start_page" => 10,
          "started_at" => local_noon(Stats.today())
        })

      {:ok, _} =
        Reading.finish_session(session, %{
          "end_page" => 10,
          "ended_at" => DateTime.add(local_noon(Stats.today()), 1, :hour)
        })

      conn = get(conn, ~p"/api/stats/47/streak")
      assert json_response(conn, 200)["data"] == %{"current" => 0, "record" => 0}
    end

    test "record is the longest past run when it beats the current streak", %{conn: conn} do
      entry = reading_list_entry_fixture(%{user_id: 48})

      for days_ago <- [10, 11, 12, 13], do: read_on(entry.id, Date.add(Stats.today(), -days_ago))
      for days_ago <- [0, 1], do: read_on(entry.id, Date.add(Stats.today(), -days_ago))

      conn = get(conn, ~p"/api/stats/48/streak")
      assert json_response(conn, 200)["data"] == %{"current" => 2, "record" => 4}
    end

    test "record is kept when the current streak is broken", %{conn: conn} do
      entry = reading_list_entry_fixture(%{user_id: 49})

      for days_ago <- [5, 6, 7], do: read_on(entry.id, Date.add(Stats.today(), -days_ago))

      conn = get(conn, ~p"/api/stats/49/streak")
      assert json_response(conn, 200)["data"] == %{"current" => 0, "record" => 3}
    end

    test "attributes a late-evening session to the local day, not the UTC day", %{conn: conn} do
      entry = reading_list_entry_fixture(%{user_id: 50})

      # 22:30 local yesterday is already today in UTC; it must count as yesterday.
      yesterday = Date.add(Stats.today(), -1)
      late_evening = DateTime.add(local_noon(yesterday), 10 * 60 + 30, :minute)

      session =
        session_fixture(entry.id, %{"start_page" => 0, "started_at" => late_evening})

      {:ok, _} =
        Reading.finish_session(session, %{"end_page" => 10, "ended_at" => late_evening})

      read_on(entry.id, Date.add(Stats.today(), -2))

      conn = get(conn, ~p"/api/stats/50/streak")
      assert json_response(conn, 200)["data"] == %{"current" => 2, "record" => 2}
    end
  end

  defp read_on(entry_id, date) do
    session =
      session_fixture(entry_id, %{"start_page" => 0, "started_at" => local_noon(date)})

    {:ok, _} =
      Reading.finish_session(session, %{
        "end_page" => 10,
        "ended_at" => DateTime.add(local_noon(date), 1, :hour)
      })
  end

  defp read_pages_on(entry_id, date, start_page, end_page) do
    session =
      session_fixture(entry_id, %{"start_page" => start_page, "started_at" => local_noon(date)})

    {:ok, _} =
      Reading.finish_session(session, %{
        "end_page" => end_page,
        "ended_at" => DateTime.add(local_noon(date), 1, :hour)
      })
  end

  defp entry_stats(conn, entry) do
    conn
    |> get(~p"/api/reading_list_entries/#{entry}/stats")
    |> json_response(200)
    |> Map.fetch!("data")
  end

  # Noon on `date` in the app's timezone, expressed as a UTC datetime.
  defp local_noon(date) do
    DateTime.new!(date, ~T[12:00:00])
    |> DateTime.add(-Application.fetch_env!(:fun_library, :utc_offset_minutes), :minute)
  end
end
