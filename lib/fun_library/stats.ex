defmodule FunLibrary.Stats do
  @moduledoc """
  Read-only reading statistics, derived from reading list entries, reading
  sessions, and reading goals.

  ## Reading days

  Every day-based stat (streak, activity, pace) uses one rule, the
  glossary's **Reading day**: a session counts when it is finished and
  advanced pages (`end_page > start_page`), and it counts entirely on the
  calendar day its `ended_at` falls on in the app's timezone (`AppTime`) —
  a session crossing midnight belongs to the day it ended. The rule lives
  in `reading_session?/1` and `reading_day/1`; nothing else restates it.

  ## Daily highlight

  Eligible highlights are the user's session highlights of at most
  120 characters (non-blank), ordered by session id. With `n` eligible
  highlights and `d` the app-timezone date as days since 1970-01-01, days
  are grouped into cycles of `n` consecutive days: cycle `div(d, n)` shows
  the highlights in a stable shuffle seeded by the cycle number (sorted by
  `:erlang.phash2({cycle, session_id})`, a portable hash), and day `d`
  shows position `rem(d, n)` of that shuffle. So the pick is fixed for a
  day, and every eligible highlight is shown once before any repeats.
  Adding or removing an eligible highlight changes `n` and so starts a new
  sequence; the last highlight of one cycle may coincide with the first of
  the next.
  """

  import Ecto.Query, warn: false
  alias FunLibrary.{AppTime, Reading, Repo}
  alias FunLibrary.Library.Book
  alias FunLibrary.Reading.{Goal, ReadingListEntry, Session}

  @daily_highlight_max_length 120
  @pace_window_days 7
  @epoch ~D[1970-01-01]

  @doc """
  Returns the dashboard summary for a user: goal progress for each of
  their goals, the reader's open session (a `%Session{}` or `nil`), and a
  currently-reading snapshot with each entry's last session time, current
  page, pace and days left.
  """
  def summary(user_id) do
    today = today()

    %{
      goals: list_goals(user_id) |> Enum.map(&goal_progress/1),
      open_session: Reading.get_open_session_for_user(user_id),
      currently_reading:
        currently_reading_entries(user_id) |> Enum.map(&currently_reading_entry(&1, today))
    }
  end

  @doc """
  Returns the user's reading activity for the last `days` days ending today
  (app timezone): one `%{date, pages_read, minutes}` per reading day, oldest
  first, omitting days without reading. `minutes` is the summed duration of
  that day's counted sessions, rounded to whole minutes.
  """
  def activity(user_id, days \\ 84) when is_integer(days) and days > 0 do
    today = today()
    window = Date.range(Date.add(today, 1 - days), today)

    user_reading_sessions(user_id)
    |> Enum.group_by(&reading_day/1)
    |> Enum.filter(fn {date, _sessions} -> date in window end)
    |> Enum.map(fn {date, sessions} ->
      seconds = sessions |> Enum.map(&DateTime.diff(&1.ended_at, &1.started_at)) |> Enum.sum()

      %{date: date, pages_read: pages_read(sessions), minutes: round(seconds / 60)}
    end)
    |> Enum.sort_by(& &1.date, Date)
  end

  @doc """
  Returns the user's daily highlight for `date` (default: today in the app's
  timezone) as `%{session_id, entry_id, book_id, book_title, highlight}`, or
  `nil` when no highlight qualifies. See the moduledoc for how it is picked.
  """
  def daily_highlight(user_id, date \\ today()) do
    case eligible_highlights(user_id) do
      [] ->
        nil

      highlights ->
        n = length(highlights)
        day = Date.diff(date, @epoch)
        cycle = Integer.floor_div(day, n)

        highlights
        |> Enum.sort_by(&{:erlang.phash2({cycle, &1.session_id}), &1.session_id})
        |> Enum.at(Integer.mod(day, n))
    end
  end

  @doc """
  Returns per-entry stats: percent complete, days elapsed, the reading
  span, and a pages-read-per-day series (bucketed by the day each session
  ended, in the app's timezone, and limited to the reading span).

  The reading span is `%{start_date, end_date}`, or `nil` when the entry
  has no start date. See `docs/adr/0003-reading-span-bounds-the-book-chart.md`.

  Raises `Ecto.NoResultsError` if the reading list entry does not exist.
  """
  def entry_stats(entry_id) do
    entry = Repo.get!(ReadingListEntry, entry_id) |> Repo.preload(:book)
    sessions = list_sessions(entry_id)
    span = reading_span(entry, sessions)

    %{
      percent_complete: percent_complete(entry, sessions),
      days_elapsed: days_elapsed(entry),
      reading_span: span,
      pages_per_day: pages_per_day(sessions, span)
    }
  end

  @doc """
  Returns the user's current streak (consecutive reading days ending today,
  or yesterday if today has no reading yet) and their streak record (the
  longest run of consecutive reading days in their whole history).
  """
  def streak(user_id) do
    reading_dates = reading_dates(user_id)
    today = today()

    start_date =
      if MapSet.member?(reading_dates, today) do
        today
      else
        Date.add(today, -1)
      end

    %{current: count_streak(reading_dates, start_date), record: longest_run(reading_dates)}
  end

  defdelegate today, to: AppTime
  defdelegate local_date(datetime), to: AppTime

  defp goal_progress(%Goal{} = goal) do
    books_finished =
      Repo.aggregate(
        from(e in ReadingListEntry,
          where:
            e.user_id == ^goal.user_id and
              e.status == :read and
              e.finished_at >= ^goal.period_start and
              e.finished_at <= ^goal.period_end
        ),
        :count
      )

    %{
      goal_id: goal.id,
      period_type: goal.period_type,
      period_start: goal.period_start,
      period_end: goal.period_end,
      target_books: goal.target_books,
      books_finished: books_finished
    }
  end

  defp list_goals(user_id) do
    Repo.all(from g in Goal, where: g.user_id == ^user_id)
  end

  defp currently_reading_entries(user_id) do
    Repo.all(
      from e in ReadingListEntry,
        where: e.user_id == ^user_id and e.status == :reading,
        preload: :book
    )
  end

  defp currently_reading_entry(%ReadingListEntry{} = entry, today) do
    sessions = list_sessions(entry.id)
    current_page = current_page(sessions)
    pace = pace(entry, sessions, today)

    %{
      entry_id: entry.id,
      book_id: entry.book_id,
      title: entry.book.title,
      percent_complete: percent_complete(entry, sessions),
      last_session_at: last_session_at(sessions),
      current_page: current_page,
      pace: pace && Float.round(pace, 1),
      days_left: days_left(entry, current_page, pace)
    }
  end

  defp last_session_at([]), do: nil
  defp last_session_at(sessions), do: List.last(sessions).started_at

  # Pages per day over the last 7 days (today included); when that is zero,
  # pages read so far over the days since the start date (at least 1). `nil`
  # when neither is positive. Unrounded; the summary rounds for display.
  defp pace(%ReadingListEntry{} = entry, sessions, today) do
    reading_sessions = Enum.filter(sessions, &reading_session?/1)
    window = Date.range(Date.add(today, 1 - @pace_window_days), today)

    recent_pages =
      reading_sessions |> Enum.filter(&(reading_day(&1) in window)) |> pages_read()

    total_pages_read = pages_read(reading_sessions)

    cond do
      recent_pages > 0 ->
        recent_pages / @pace_window_days

      total_pages_read > 0 and not is_nil(entry.started_at) ->
        total_pages_read / max(1, Date.diff(today, entry.started_at))

      true ->
        nil
    end
  end

  defp days_left(_entry, _current_page, nil), do: nil

  defp days_left(%ReadingListEntry{} = entry, current_page, pace) do
    page = current_page || 0

    case entry.total_pages || entry.book.total_pages do
      total_pages when is_integer(total_pages) and total_pages > page ->
        ceil((total_pages - page) / pace)

      _unknown_or_nothing_remaining ->
        nil
    end
  end

  defp eligible_highlights(user_id) do
    Repo.all(
      from s in Session,
        join: e in ReadingListEntry,
        on: e.id == s.reading_list_entry_id,
        join: b in Book,
        on: b.id == e.book_id,
        where: e.user_id == ^user_id and not is_nil(s.highlight),
        order_by: s.id,
        select: %{
          session_id: s.id,
          entry_id: e.id,
          book_id: b.id,
          book_title: b.title,
          highlight: s.highlight
        }
    )
    |> Enum.filter(fn %{highlight: highlight} ->
      String.trim(highlight) != "" and String.length(highlight) <= @daily_highlight_max_length
    end)
  end

  defp reading_dates(user_id) do
    user_id
    |> user_reading_sessions()
    |> MapSet.new(&reading_day/1)
  end

  # The user's sessions that make a reading day, across all their entries.
  defp user_reading_sessions(user_id) do
    Repo.all(
      from s in Session,
        join: e in ReadingListEntry,
        on: e.id == s.reading_list_entry_id,
        where: e.user_id == ^user_id and not is_nil(s.ended_at)
    )
    |> Enum.filter(&reading_session?/1)
  end

  # The Reading day rule: a finished session that advanced pages...
  defp reading_session?(%Session{ended_at: ended_at, start_page: start_page, end_page: end_page}) do
    not is_nil(ended_at) and not is_nil(end_page) and end_page > start_page
  end

  # ...counts on the app-timezone day it ended.
  defp reading_day(%Session{ended_at: ended_at}), do: local_date(ended_at)

  defp pages_read(sessions) do
    sessions |> Enum.map(&(&1.end_page - &1.start_page)) |> Enum.sum()
  end

  defp count_streak(reading_dates, date) do
    if MapSet.member?(reading_dates, date) do
      1 + count_streak(reading_dates, Date.add(date, -1))
    else
      0
    end
  end

  defp longest_run(reading_dates) do
    reading_dates
    |> Enum.sort(Date)
    |> Enum.chunk_while(
      [],
      fn
        date, [prev | _] = run ->
          if Date.diff(date, prev) == 1, do: {:cont, [date | run]}, else: {:cont, run, [date]}

        date, [] ->
          {:cont, [date]}
      end,
      fn
        [] -> {:cont, []}
        run -> {:cont, run, []}
      end
    )
    |> Enum.map(&length/1)
    |> Enum.max(fn -> 0 end)
  end

  defp list_sessions(entry_id) do
    Repo.all(
      from s in Session, where: s.reading_list_entry_id == ^entry_id, order_by: s.started_at
    )
  end

  defp percent_complete(%ReadingListEntry{} = entry, sessions) do
    case entry.total_pages || entry.book.total_pages do
      total_pages when is_nil(total_pages) or total_pages <= 0 ->
        nil

      total_pages ->
        case current_page(sessions) do
          nil -> 0.0
          current_page -> Float.round(current_page / total_pages * 100, 1)
        end
    end
  end

  defp current_page([]), do: nil

  defp current_page(sessions) do
    case List.last(sessions) do
      %Session{end_page: end_page} when not is_nil(end_page) -> end_page
      %Session{start_page: start_page} -> start_page
    end
  end

  defp days_elapsed(%ReadingListEntry{started_at: nil}), do: nil

  defp days_elapsed(%ReadingListEntry{started_at: started_at, finished_at: finished_at}) do
    Date.diff(finished_at || today(), started_at)
  end

  defp reading_span(%ReadingListEntry{started_at: nil}, _sessions), do: nil

  defp reading_span(%ReadingListEntry{started_at: start_date} = entry, sessions) do
    end_date =
      case entry.status do
        :read -> entry.finished_at || last_reading_day(sessions) || start_date
        :reading -> today()
        _ -> last_reading_day(sessions) || start_date
      end

    %{start_date: start_date, end_date: Enum.max([start_date, end_date], Date)}
  end

  defp last_reading_day(sessions) do
    sessions
    |> Enum.filter(&reading_session?/1)
    |> Enum.map(&reading_day/1)
    |> Enum.max(Date, fn -> nil end)
  end

  defp pages_per_day(_sessions, nil), do: []

  defp pages_per_day(sessions, %{start_date: start_date, end_date: end_date}) do
    span = Date.range(start_date, end_date)

    sessions
    |> Enum.filter(&(&1.ended_at && &1.end_page))
    |> Enum.filter(&(local_date(&1.ended_at) in span))
    |> Enum.group_by(&local_date(&1.ended_at), &(&1.end_page - &1.start_page))
    |> Enum.map(fn {date, pages_read} -> %{date: date, pages_read: Enum.sum(pages_read)} end)
    |> Enum.sort_by(& &1.date, Date)
  end
end
