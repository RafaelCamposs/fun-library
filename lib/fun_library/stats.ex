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
  pages-read-per-day series (bucketed by the day each session ended).

  Raises `Ecto.NoResultsError` if the reading list entry does not exist.
  """
  def entry_stats(entry_id) do
    entry = Repo.get!(ReadingListEntry, entry_id) |> Repo.preload(:book)
    sessions = list_sessions(entry_id)

    %{
      percent_complete: percent_complete(entry.book, sessions),
      days_elapsed: days_elapsed(entry),
      pages_per_day: pages_per_day(sessions)
    }
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
      percent_complete: percent_complete(entry.book, list_sessions(entry.id))
    }
  end

  defp list_sessions(entry_id) do
    Repo.all(
      from s in Session, where: s.reading_list_entry_id == ^entry_id, order_by: s.started_at
    )
  end

  defp percent_complete(%{total_pages: total_pages}, _sessions)
       when is_nil(total_pages) or total_pages <= 0,
       do: nil

  defp percent_complete(%{total_pages: total_pages}, sessions) do
    case current_page(sessions) do
      nil -> 0.0
      current_page -> Float.round(current_page / total_pages * 100, 1)
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
    Date.diff(finished_at || Date.utc_today(), started_at)
  end

  defp pages_per_day(sessions) do
    sessions
    |> Enum.filter(&(&1.ended_at && &1.end_page))
    |> Enum.group_by(&DateTime.to_date(&1.ended_at), &(&1.end_page - &1.start_page))
    |> Enum.map(fn {date, pages_read} -> %{date: date, pages_read: Enum.sum(pages_read)} end)
    |> Enum.sort_by(& &1.date, Date)
  end
end
