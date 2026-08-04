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
  Generate a goal.
  """
  def goal_fixture(attrs \\ %{}) do
    {:ok, goal} =
      attrs
      |> Enum.into(%{
        period_end: ~D[2026-07-18],
        period_start: ~D[2026-07-18],
        period_type: :annual,
        target_books: 42,
        user_id: 42
      })
      |> FunLibrary.Reading.create_goal()

    goal
  end
end
