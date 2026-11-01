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

  describe "summary/1 goals" do
    test "holds current goals only, in the summary shape" do
      today = Stats.today()
      this_year = Date.new!(today.year, 1, 1)
      this_month = Date.beginning_of_month(today)

      annual = goal_fixture(user_id: @user_id, period_start: this_year, target_books: 12)

      monthly =
        goal_fixture(
          user_id: @user_id,
          period_type: :monthly,
          period_start: this_month,
          target_books: 2
        )

      goal_fixture(user_id: @user_id, period_start: Date.new!(today.year + 1, 1, 1))
      insert_goal!(user_id: @user_id, period_start: Date.new!(today.year - 1, 1, 1))
      goal_fixture(user_id: @user_id + 1, period_start: this_year)

      reading_list_entry_fixture(user_id: @user_id, status: :read, finished_at: today)

      assert Stats.summary(@user_id).goals == [
               %{
                 goal_id: annual.id,
                 period_type: :annual,
                 period_start: this_year,
                 period_end: Date.new!(today.year, 12, 31),
                 target_books: 12,
                 books_finished: 1
               },
               %{
                 goal_id: monthly.id,
                 period_type: :monthly,
                 period_start: this_month,
                 period_end: Date.end_of_month(today),
                 target_books: 2,
                 books_finished: 1
               }
             ]
    end
  end

  describe "goal_progress/2" do
    test "counts the user's read entries finished within the period, bounds included" do
      goal = insert_goal!(user_id: @user_id, period_type: :monthly, period_start: ~D[2026-10-01])

      for finished_at <- [~D[2026-10-01], ~D[2026-10-31], ~D[2026-09-30], ~D[2026-11-01]] do
        finished_entry(finished_at)
      end

      reading_list_entry_fixture(user_id: @user_id, status: :reading, finished_at: ~D[2026-10-10])

      reading_list_entry_fixture(
        user_id: @user_id + 1,
        status: :read,
        finished_at: ~D[2026-10-10]
      )

      assert %{books_finished: 2, period_end: ~D[2026-10-31]} =
               Stats.goal_progress(goal, ~D[2026-10-20])
    end

    test "a finish counts toward both the annual and the monthly goal" do
      annual = insert_goal!(user_id: @user_id, period_type: :annual, period_start: ~D[2026-01-01])

      monthly =
        insert_goal!(user_id: @user_id, period_type: :monthly, period_start: ~D[2026-11-01])

      finished_entry(~D[2026-11-05])

      assert %{books_finished: 1, period_end: ~D[2026-12-31]} =
               Stats.goal_progress(annual, ~D[2026-11-20])

      assert %{books_finished: 1, period_end: ~D[2026-11-30]} =
               Stats.goal_progress(monthly, ~D[2026-11-20])
    end

    test "derives state and outcome from today" do
      goal =
        insert_goal!(
          user_id: @user_id,
          period_type: :monthly,
          period_start: ~D[2026-10-01],
          target_books: 2
        )

      finished_entry(~D[2026-10-04])

      assert %{state: :upcoming, outcome: nil} = Stats.goal_progress(goal, ~D[2026-09-30])
      assert %{state: :current, outcome: nil} = Stats.goal_progress(goal, ~D[2026-10-01])
      assert %{state: :current, outcome: nil} = Stats.goal_progress(goal, ~D[2026-10-31])

      assert %{state: :closed, outcome: :missed, books_finished: 1} =
               Stats.goal_progress(goal, ~D[2026-11-01])

      # Backfilling a finish date into the closed period flips the outcome.
      finished_entry(~D[2026-10-20])

      assert %{state: :closed, outcome: :achieved, books_finished: 2} =
               Stats.goal_progress(goal, ~D[2026-11-01])
    end
  end

  describe "goal_books/1" do
    setup do
      %{
        october:
          insert_goal!(user_id: @user_id, period_type: :monthly, period_start: ~D[2026-10-01]),
        november:
          insert_goal!(user_id: @user_id, period_type: :monthly, period_start: ~D[2026-11-01])
      }
    end

    test "lists books finished in the period by finish date, hand-logged ones included",
         %{october: october} do
      dune = reading_entry(100)
      read(dune, ~D[2026-10-02], 0, 50)
      read(dune, ~D[2026-10-28], 50, 100)

      hand_logged = finished_entry(~D[2026-10-12])
      finished_entry(~D[2026-09-30])

      assert %{finished: [first, second], also_read: []} = Stats.goal_books(october)

      assert first == %{
               entry_id: hand_logged.id,
               book_id: hand_logged.book_id,
               title: hand_logged.book.title,
               cover_url: hand_logged.book.cover_url,
               finished_at: ~D[2026-10-12]
             }

      assert %{entry_id: dune_id, finished_at: ~D[2026-10-28]} = second
      assert dune_id == dune.id
    end

    test "labels books read in the period but not finished there", %{october: october} do
      reading = reading_entry(100)
      read(reading, ~D[2026-10-05], 0, 10)

      carried_by_reading = reading_entry(100)
      read(carried_by_reading, ~D[2026-10-30], 0, 20)
      read(carried_by_reading, ~D[2026-11-02], 20, 40)

      carried_by_finish = reading_entry(100)
      read(carried_by_finish, ~D[2026-10-20], 0, 50)
      set_entry(carried_by_finish, status: :read, finished_at: ~D[2026-11-05])

      stopped = reading_entry(100)
      read(stopped, ~D[2026-10-10], 0, 10)
      set_entry(stopped, status: :stopped)

      unfinished = reading_entry(100)
      read(unfinished, ~D[2026-10-15], 0, 10)
      set_entry(unfinished, status: :unfinished)

      # Only possible through hand edits: shown with their status, never counted.
      read_before = reading_entry(100)
      read(read_before, ~D[2026-10-08], 0, 10)
      set_entry(read_before, status: :read, finished_at: ~D[2026-09-20])

      want_to = reading_entry(100)
      read(want_to, ~D[2026-10-09], 0, 10)
      set_entry(want_to, status: :want_to)

      assert %{finished: [], also_read: also_read} = Stats.goal_books(october)

      assert Enum.map(also_read, &{&1.entry_id, &1.label, &1.last_reading_day}) == [
               {reading.id, :reading, ~D[2026-10-05]},
               {read_before.id, :read, ~D[2026-10-08]},
               {want_to.id, :want_to, ~D[2026-10-09]},
               {stopped.id, :stopped, ~D[2026-10-10]},
               {unfinished.id, :unfinished, ~D[2026-10-15]},
               {carried_by_finish.id, :carried_over, ~D[2026-10-20]},
               {carried_by_reading.id, :carried_over, ~D[2026-10-30]}
             ]

      assert %{book_id: book_id, title: title, cover_url: cover_url} = hd(also_read)

      assert {book_id, title, cover_url} ==
               {reading.book_id, reading.book.title, reading.book.cover_url}
    end

    test "a book spanning the boundary is carried over, then shows its outcome",
         %{october: october, november: november} do
      spanning = reading_entry(100)
      read(spanning, ~D[2026-10-30], 0, 50)
      read(spanning, ~D[2026-11-03], 50, 100)

      still_reading = reading_entry(100)
      read(still_reading, ~D[2026-10-31], 0, 10)
      read(still_reading, ~D[2026-11-01], 10, 20)

      assert %{finished: [], also_read: october_also_read} = Stats.goal_books(october)

      assert Enum.map(october_also_read, &{&1.entry_id, &1.label}) == [
               {spanning.id, :carried_over},
               {still_reading.id, :carried_over}
             ]

      assert %{finished: [finished], also_read: [also_read]} = Stats.goal_books(november)
      assert {finished.entry_id, finished.finished_at} == {spanning.id, ~D[2026-11-03]}

      assert {also_read.entry_id, also_read.label, also_read.last_reading_day} ==
               {still_reading.id, :reading, ~D[2026-11-01]}
    end

    test "a book read across the new year is carried over in the earlier annual goal" do
      year_2025 = insert_goal!(user_id: @user_id, period_start: ~D[2025-01-01])
      year_2026 = insert_goal!(user_id: @user_id, period_start: ~D[2026-01-01])

      entry = reading_entry(100)
      read(entry, ~D[2025-12-30], 0, 50)
      read(entry, ~D[2026-01-03], 50, 100)

      assert %{finished: [], also_read: [%{label: :carried_over}]} = Stats.goal_books(year_2025)

      assert %{finished: [%{finished_at: ~D[2026-01-03]}], also_read: []} =
               Stats.goal_books(year_2026)
    end

    test "only reading days count: sessions belong to the day they ended, and must advance pages",
         %{october: october} do
      crossing_in = reading_entry(100)
      read_between(crossing_in, {~D[2026-09-30], ~T[23:30:00]}, {~D[2026-10-01], ~T[00:30:00]})

      crossing_out = reading_entry(100)
      read_between(crossing_out, {~D[2026-10-31], ~T[23:30:00]}, {~D[2026-11-01], ~T[00:30:00]})

      no_progress = reading_entry(100)
      read(no_progress, ~D[2026-10-12], 10, 10)

      other_reader =
        reading_list_entry_fixture(user_id: @user_id + 1, status: :reading)

      read(other_reader, ~D[2026-10-12], 0, 10)

      assert %{also_read: [also_read]} = Stats.goal_books(october)
      assert {also_read.entry_id, also_read.last_reading_day} == {crossing_in.id, ~D[2026-10-01]}
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

  defp finished_entry(finished_at) do
    reading_list_entry_fixture(user_id: @user_id, status: :read, finished_at: finished_at)
  end

  defp set_entry(entry, attrs) do
    {:ok, entry} = Reading.update_reading_list_entry(entry, Map.new(attrs))
    entry
  end

  # A session from `started` to `ended`, each `{date, time}` in the app's timezone.
  defp read_between(entry, {start_date, start_time}, {end_date, end_time}) do
    session =
      session_fixture(entry.id, %{
        "start_page" => 0,
        "started_at" => local_time(start_date, start_time)
      })

    {:ok, session} =
      Reading.finish_session(session, %{
        "end_page" => 10,
        "ended_at" => local_time(end_date, end_time)
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

  # `time` (default 08:00) on `date` in the app's timezone, as a UTC datetime.
  defp local_time(date, time \\ ~T[08:00:00]) do
    DateTime.new!(date, time)
    |> DateTime.add(-Application.fetch_env!(:fun_library, :utc_offset_minutes), :minute)
  end
end
