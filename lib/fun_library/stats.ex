defmodule FunLibrary.Stats do
  @moduledoc """
  Read-only reading statistics, derived from reading list entries, reading
  sessions, and reading goals.
  """

  import Ecto.Query, warn: false
  alias FunLibrary.Repo
  alias FunLibrary.Reading.{Goal, ReadingListEntry, Session}

  @doc """
  Returns the dashboard summary for a user: goal progress for each of
  their goals, and a currently-reading snapshot.
  """
  def summary(user_id) do
    %{
      goals: list_goals(user_id) |> Enum.map(&goal_progress/1),
      currently_reading:
        currently_reading_entries(user_id) |> Enum.map(&currently_reading_entry/1)
    }
  end

  @doc """
  Returns per-entry stats: percent complete, days elapsed, and a
  pages-read-per-day series (bucketed by the day each session ended, in
  the app's timezone).

  Raises `Ecto.NoResultsError` if the reading list entry does not exist.
  """
  def entry_stats(entry_id) do
    entry = Repo.get!(ReadingListEntry, entry_id) |> Repo.preload(:book)
    sessions = list_sessions(entry_id)

    %{
      percent_complete: percent_complete(entry, sessions),
      days_elapsed: days_elapsed(entry),
      pages_per_day: pages_per_day(sessions)
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

  @doc """
  Returns today's date in the app's timezone (see `:utc_offset_minutes`).
  """
  def today, do: local_date(DateTime.utc_now())

  @doc """
  Returns the calendar date of a UTC datetime in the app's timezone.
  """
  def local_date(%DateTime{} = datetime) do
    datetime
    |> DateTime.add(Application.fetch_env!(:fun_library, :utc_offset_minutes), :minute)
    |> DateTime.to_date()
  end

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

  defp currently_reading_entry(%ReadingListEntry{} = entry) do
    %{
      entry_id: entry.id,
      book_id: entry.book_id,
      title: entry.book.title,
      percent_complete: percent_complete(entry, list_sessions(entry.id))
    }
  end

  defp reading_dates(user_id) do
    Repo.all(
      from s in Session,
        join: e in ReadingListEntry,
        on: e.id == s.reading_list_entry_id,
        where:
          e.user_id == ^user_id and not is_nil(s.ended_at) and
            s.end_page > s.start_page,
        select: s.ended_at
    )
    |> Enum.map(&local_date/1)
    |> MapSet.new()
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

  defp pages_per_day(sessions) do
    sessions
    |> Enum.filter(&(&1.ended_at && &1.end_page))
    |> Enum.group_by(&local_date(&1.ended_at), &(&1.end_page - &1.start_page))
    |> Enum.map(fn {date, pages_read} -> %{date: date, pages_read: Enum.sum(pages_read)} end)
    |> Enum.sort_by(& &1.date, Date)
  end
end
