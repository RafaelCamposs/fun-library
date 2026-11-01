defmodule FunLibrary.ReadingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FunLibrary.Reading` context.
  """

  import FunLibrary.LibraryFixtures

  @doc """
  Generate a reading list entry (defaults to `:want_to`, for a freshly
  created book unless `:book_id` is given).
  """
  def reading_list_entry_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    book_id = Map.get(attrs, :book_id, book_fixture().id)

    {:ok, entry} =
      attrs
      |> Map.delete(:book_id)
      |> Enum.into(%{user_id: 42, status: :want_to, book_id: book_id})
      |> FunLibrary.Reading.create_reading_list_entry()

    entry
  end

  @doc """
  Generate a reading session (started, not finished) for a reading list
  entry.
  """
  def session_fixture(entry_id, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        "start_page" => 0,
        "started_at" => ~U[2026-07-18 18:46:00Z]
      })

    {:ok, session} = FunLibrary.Reading.start_session(entry_id, attrs)

    session
  end

  @doc """
  Generate a goal through `Reading.create_goal/3`, so it must be for a
  current or upcoming period as of `:today` (default: the app's today).
  Defaults to an annual goal for `:today`'s year.
  """
  def goal_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    {user_id, attrs} = Map.pop(attrs, :user_id, 42)
    {today, attrs} = Map.pop(attrs, :today, FunLibrary.AppTime.today())

    {:ok, goal} =
      attrs
      |> Enum.into(%{
        period_type: :annual,
        period_start: Date.new!(today.year, 1, 1),
        target_books: 42
      })
      |> then(&FunLibrary.Reading.create_goal(user_id, &1, today))

    goal
  end

  @doc """
  Insert a goal directly, skipping the changeset's rules: for goals in
  periods that have already ended (closed goals), which can't be created
  through the API.
  """
  def insert_goal!(attrs) do
    FunLibrary.Repo.insert!(
      struct!(
        FunLibrary.Reading.Goal,
        Enum.into(attrs, %{user_id: 42, period_type: :annual, target_books: 42})
      )
    )
  end
end
