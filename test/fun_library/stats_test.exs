defmodule FunLibrary.StatsTest do
  use FunLibrary.DataCase

  import FunLibrary.LibraryFixtures
  import FunLibrary.ReadingFixtures
  alias FunLibrary.{Reading, Stats}

  @user_id 61

  describe "summary/1 currently reading" do
    test "has no last session, current page, pace or days left without sessions" do
      reading_entry(500)

      assert [item] = Stats.summary(@user_id).currently_reading
      assert %{last_session_at: nil, current_page: nil, pace: nil, days_left: nil} = item
    end

    test "averages the last 7 days, today included, and derives days left" do
      entry = reading_entry(500)

      read(entry, days_ago(10), 0, 100)
      read(entry, days_ago(2), 100, 170)
      %{started_at: last_started_at} = read(entry, days_ago(0), 170, 224)

      assert [item] = Stats.summary(@user_id).currently_reading
      # (70 + 54) pages / 7 days = 17.71..., 276 pages left / 17.71... = 15.6 → 16
      assert item.pace == 17.7
      assert item.days_left == 16
      assert item.current_page == 224
      assert item.last_session_at == last_started_at
    end

    test "leaves a session that ended 7 days ago out of the pace window" do
      entry = reading_entry(500)

      read(entry, days_ago(7), 0, 70)
      read(entry, days_ago(6), 70, 77)

      assert [%{pace: 1.0}] = Stats.summary(@user_id).currently_reading
    end

    test "falls back to pages read since the start date when the last 7 days are zero" do
      entry = reading_entry(100)

      read(entry, days_ago(20), 0, 30)
      read(entry, days_ago(10), 30, 60)

      assert [item] = Stats.summary(@user_id).currently_reading
      # 60 pages over 20 days since the start date; 40 left / 3.0 → 14
      assert item.pace == 3.0
      assert item.days_left == 14
    end

    test "fallback divides by at least one day" do
      entry = reading_entry(100)
      read(entry, days_ago(10), 0, 30)
      {:ok, _} = Reading.update_reading_list_entry(entry, %{started_at: Stats.today()})

      assert [%{pace: 30.0, days_left: 3}] = Stats.summary(@user_id).currently_reading
    end

    test "has no pace when no session advanced pages" do
      entry = reading_entry(100)
      read(entry, days_ago(1), 12, 12)

      assert [item] = Stats.summary(@user_id).currently_reading
      assert %{pace: nil, days_left: nil, current_page: 12} = item
    end

    test "uses the open session's start page as the current page" do
      entry = reading_entry(100)
      read(entry, days_ago(1), 0, 20)

      open =
        session_fixture(entry.id, %{"start_page" => 20, "started_at" => local_time(days_ago(0))})

      assert [item] = Stats.summary(@user_id).currently_reading
      assert item.current_page == 20
      assert item.last_session_at == open.started_at
    end

    test "has no days left without a page count" do
      entry = reading_entry(nil)
      read(entry, days_ago(1), 0, 20)

      assert [%{pace: pace, days_left: nil}] = Stats.summary(@user_id).currently_reading
      assert pace > 0
    end

    test "uses the entry's total_pages override for days left" do
      entry = reading_entry(1000)
      {:ok, entry} = Reading.update_entry_pages(entry, %{"total_pages" => 84})
      read(entry, days_ago(1), 0, 70)

      # 70 / 7 = 10.0 pages a day, 14 pages left of the override's 84
      assert [%{pace: 10.0, days_left: 2}] = Stats.summary(@user_id).currently_reading
    end

    test "has no days left when nothing remains" do
      entry = reading_entry(1000)
      read(entry, days_ago(1), 0, 70)
      {:ok, _} = Reading.update_entry_pages(entry, %{"total_pages" => 70})

      assert [%{pace: 10.0, days_left: nil}] = Stats.summary(@user_id).currently_reading
    end
  end

  describe "summary/1 open session" do
    test "is the reader's open session on any entry, or nil" do
      entry = reading_entry(100)
      assert Stats.summary(@user_id).open_session == nil

      open = session_fixture(entry.id, %{"start_page" => 0})

      assert Stats.summary(@user_id).open_session.id == open.id
      assert Stats.summary(@user_id + 1).open_session == nil
    end
  end

  describe "daily_highlight/2" do
    test "is nil when the user has no highlights" do
      read(reading_entry(100), days_ago(1), 0, 10)

      assert Stats.daily_highlight(@user_id) == nil
    end

    test "is nil when no highlight is short enough" do
      entry = reading_entry(100)
      highlight(read(entry, days_ago(2), 0, 10), String.duplicate("a", 121))
      highlight(read(entry, days_ago(1), 10, 20), "   ")

      assert Stats.daily_highlight(@user_id) == nil
    end

    test "never picks a highlight over 120 characters" do
      entry = reading_entry(100)
      highlight(read(entry, days_ago(2), 0, 10), String.duplicate("a", 121))
      short = highlight(read(entry, days_ago(1), 10, 20), String.duplicate("b", 120))

      for offset <- 0..20 do
        assert Stats.daily_highlight(@user_id, Date.add(Stats.today(), offset)).session_id ==
                 short.id
      end
    end

    test "returns the session, entry, book and highlight" do
      book = book_fixture(%{title: "Oathbringer", total_pages: 100})
      entry = reading_list_entry_fixture(user_id: @user_id, status: :reading, book_id: book.id)
      session = highlight(read(entry, days_ago(1), 0, 10), "Journey before destination.")

      assert Stats.daily_highlight(@user_id) == %{
               session_id: session.id,
               entry_id: entry.id,
               book_id: book.id,
               book_title: "Oathbringer",
               highlight: "Journey before destination."
             }
    end

    test "is stable within a day and shows every highlight once per cycle" do
      entry = reading_entry(1000)

      ids =
        for i <- 0..4 do
          highlight(read(entry, days_ago(10 - i), i * 10, i * 10 + 10), "highlight #{i}").id
        end

      cycle_start = first_day_of_cycle(Stats.today(), length(ids))
      days = Enum.map(0..4, &Date.add(cycle_start, &1))
      picks = Enum.map(days, &Stats.daily_highlight(@user_id, &1).session_id)

      assert Enum.sort(picks) == Enum.sort(ids)
      assert Enum.map(days, &Stats.daily_highlight(@user_id, &1).session_id) == picks
    end

    test "changes from one day to the next" do
      entry = reading_entry(1000)
      highlight(read(entry, days_ago(3), 0, 10), "first")
      highlight(read(entry, days_ago(2), 10, 20), "second")
      highlight(read(entry, days_ago(1), 20, 30), "third")

      day = first_day_of_cycle(Stats.today(), 3)

      assert Stats.daily_highlight(@user_id, day) !=
               Stats.daily_highlight(@user_id, Date.add(day, 1))
    end
  end

  defp reading_entry(total_pages) do
    book = book_fixture(%{total_pages: total_pages})
    reading_list_entry_fixture(user_id: @user_id, status: :reading, book_id: book.id)
  end

  defp read(entry, date, start_page, end_page) do
    session =
      session_fixture(entry.id, %{"start_page" => start_page, "started_at" => local_time(date)})

    {:ok, session} =
      Reading.finish_session(session, %{
        "end_page" => end_page,
        "ended_at" => DateTime.add(local_time(date), 1, :hour)
      })

    session
  end

  defp highlight(session, text) do
    {:ok, session} = Reading.update_session_highlight(session, %{"highlight" => text})
    session
  end

  defp days_ago(days), do: Date.add(Stats.today(), -days)

  # The latest day on or before `date` that starts a cycle of `n` days.
  defp first_day_of_cycle(date, n) do
    Date.add(date, -Integer.mod(Date.diff(date, ~D[1970-01-01]), n))
  end

  # 08:00 on `date` in the app's timezone, as a UTC datetime.
  defp local_time(date) do
    DateTime.new!(date, ~T[08:00:00])
    |> DateTime.add(-Application.fetch_env!(:fun_library, :utc_offset_minutes), :minute)
  end
end
