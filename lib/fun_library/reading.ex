defmodule FunLibrary.Reading do
  @moduledoc """
  The Reading context — a user's reading list, sessions, and goals.
  """

  import Ecto.Query, warn: false
  alias FunLibrary.Repo
  alias FunLibrary.Library
  alias FunLibrary.Reading.ReadingListEntry

  ## Reading list entries

  @doc """
  Returns the list of reading list entries for a user.
  """
  def list_reading_list_entries(user_id) do
    Repo.all(from e in ReadingListEntry, where: e.user_id == ^user_id, preload: :book)
  end

  @doc """
  Gets a single reading list entry.

  Raises `Ecto.NoResultsError` if the entry does not exist.
  """
  def get_reading_list_entry!(id), do: Repo.get!(ReadingListEntry, id) |> Repo.preload(:book)

  @doc """
  Creates a reading list entry.
  """
  def create_reading_list_entry(attrs) do
    with {:ok, entry} <- %ReadingListEntry{} |> ReadingListEntry.changeset(attrs) |> Repo.insert() do
      {:ok, Repo.preload(entry, :book)}
    end
  end

  @doc """
  Updates a reading list entry.
  """
  def update_reading_list_entry(%ReadingListEntry{} = entry, attrs) do
    entry
    |> ReadingListEntry.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Sets (or clears, with `nil`) a per-entry `total_pages` override, used
  when the catalog book's page count doesn't match the user's edition.
  """
  def update_entry_pages(%ReadingListEntry{} = entry, attrs) do
    entry
    |> ReadingListEntry.pages_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a reading list entry.
  """
  def delete_reading_list_entry(%ReadingListEntry{} = entry) do
    Repo.delete(entry)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking reading list entry changes.
  """
  def change_reading_list_entry(%ReadingListEntry{} = entry, attrs \\ %{}) do
    ReadingListEntry.changeset(entry, attrs)
  end

  @doc """
  Adds a book to a user's reading list: finds-or-creates the catalog `Book`
  from `book_attrs` (see `FunLibrary.Library.find_or_create_book/1`), then
  creates a `ReadingListEntry` linking the user to it.

  `entry_attrs` may include `status` (defaults to `"want_to"`),
  `started_at`, and `finished_at` — e.g. to log a book the user already
  finished reading.
  """
  def add_to_reading_list(user_id, book_attrs, entry_attrs \\ %{}) do
    with {:ok, book} <- Library.find_or_create_book(book_attrs) do
      entry_attrs
      |> Map.new(fn {key, value} -> {to_string(key), value} end)
      |> Map.put_new("status", "want_to")
      |> Map.put("user_id", user_id)
      |> Map.put("book_id", book.id)
      |> create_reading_list_entry()
    end
  end

  ## Sessions

  alias FunLibrary.Reading.Session

  @doc """
  Returns the list of reading sessions for a reading list entry, oldest
  first.
  """
  def list_sessions_for_entry(entry_id) do
    Repo.all(
      from s in Session, where: s.reading_list_entry_id == ^entry_id, order_by: s.started_at
    )
  end

  @doc """
  Gets a single session.

  Raises `Ecto.NoResultsError` if the Session does not exist.
  """
  def get_session!(id), do: Repo.get!(Session, id)

  @doc """
  Returns the open (unfinished) session for a reading list entry, if any.
  """
  def get_open_session(entry_id) do
    Repo.one(
      from s in Session, where: s.reading_list_entry_id == ^entry_id and is_nil(s.ended_at)
    )
  end

  @doc """
  Starts a new reading session for a reading list entry.

  Fails with `{:error, :session_already_open}` if the entry already has an
  unfinished session. On success, flips the entry to `:reading` and sets
  `started_at` if needed.
  """
  def start_session(entry_id, attrs) do
    if get_open_session(entry_id) do
      {:error, :session_already_open}
    else
      attrs = Map.put(attrs, "reading_list_entry_id", entry_id)

      with {:ok, session} <- %Session{} |> Session.start_changeset(attrs) |> Repo.insert() do
        mark_entry_started(entry_id)
        {:ok, session}
      end
    end
  end

  @doc """
  Finishes an open reading session, recording the ending page and time.

  On success, flips the entry to `:read` and sets `finished_at` if the
  session's `end_page` reached the book's `total_pages`.
  """
  def finish_session(%Session{} = session, attrs) do
    changeset =
      session
      |> Session.finish_changeset(attrs)
      |> validate_end_page_within_total_pages(session.reading_list_entry_id)

    with {:ok, session} <- Repo.update(changeset) do
      maybe_finish_entry(session.reading_list_entry_id, session.end_page)
      {:ok, session}
    end
  end

  defp validate_end_page_within_total_pages(changeset, entry_id) do
    end_page = Ecto.Changeset.get_field(changeset, :end_page)
    total_pages = get_reading_list_entry!(entry_id) |> Repo.preload(:book) |> then(& &1.book.total_pages)

    if end_page && total_pages && end_page > total_pages do
      Ecto.Changeset.add_error(changeset, :end_page, "must not exceed the book's total_pages (#{total_pages})")
    else
      changeset
    end
  end

  @doc """
  Deletes a session.
  """
  def delete_session(%Session{} = session) do
    Repo.delete(session)
  end

  @doc """
  Marks a reading list entry as being read: flips a `:want_to` entry to
  `:reading` and sets `started_at` if it hasn't been set yet. No-op if
  neither applies.
  """
  def mark_entry_started(entry_id) do
    entry = get_reading_list_entry!(entry_id)

    changes =
      %{}
      |> maybe_put_change(:status, :reading, entry.status == :want_to)
      |> maybe_put_change(:started_at, Date.utc_today(), is_nil(entry.started_at))

    if changes == %{} do
      entry
    else
      {:ok, updated} = update_reading_list_entry(entry, changes)
      updated
    end
  end

  @doc """
  Marks a reading list entry as finished (`status: :read`, `finished_at`
  set) if the given page reached the book's total page count. No-op
  otherwise.
  """
  def maybe_finish_entry(entry_id, end_page) do
    entry = get_reading_list_entry!(entry_id) |> Repo.preload(:book)

    if entry.book.total_pages && end_page && end_page >= entry.book.total_pages do
      {:ok, updated} =
        update_reading_list_entry(entry, %{status: :read, finished_at: Date.utc_today()})

      updated
    else
      entry
    end
  end

  defp maybe_put_change(changes, _key, _value, false), do: changes
  defp maybe_put_change(changes, key, value, true), do: Map.put(changes, key, value)

  ## Goals

  alias FunLibrary.Reading.Goal

  @doc """
  Returns the list of reading_goals.
  """
  def list_reading_goals do
    Repo.all(Goal)
  end

  @doc """
  Gets a single goal.

  Raises `Ecto.NoResultsError` if the Goal does not exist.
  """
  def get_goal!(id), do: Repo.get!(Goal, id)

  @doc """
  Creates a goal.
  """
  def create_goal(attrs) do
    %Goal{}
    |> Goal.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a goal.
  """
  def update_goal(%Goal{} = goal, attrs) do
    goal
    |> Goal.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a goal.
  """
  def delete_goal(%Goal{} = goal) do
    Repo.delete(goal)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking goal changes.
  """
  def change_goal(%Goal{} = goal, attrs \\ %{}) do
    Goal.changeset(goal, attrs)
  end
end
