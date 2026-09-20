defmodule FunLibrary.ReadingTest do
  use FunLibrary.DataCase

  alias FunLibrary.Reading

  describe "reading_list_entries" do
    alias FunLibrary.Reading.ReadingListEntry

    import FunLibrary.ReadingFixtures
    import FunLibrary.LibraryFixtures

    test "list_reading_list_entries/1 returns entries for the given user" do
      entry = reading_list_entry_fixture(user_id: 1)
      reading_list_entry_fixture(user_id: 2)

      assert Reading.list_reading_list_entries(1) == [entry]
    end

    test "get_reading_list_entry!/1 returns the entry with given id" do
      entry = reading_list_entry_fixture()
      assert Reading.get_reading_list_entry!(entry.id) == entry
    end

    test "create_reading_list_entry/1 rejects a duplicate (user_id, book_id) pair" do
      book = book_fixture()
      reading_list_entry_fixture(user_id: 1, book_id: book.id)

      assert {:error, changeset} =
               Reading.create_reading_list_entry(%{
                 user_id: 1,
                 book_id: book.id,
                 status: :want_to
               })

      assert "has already been taken" in errors_on(changeset).user_id
    end

    test "update_reading_list_entry/2 with valid data updates the entry" do
      entry = reading_list_entry_fixture()

      assert {:ok, %ReadingListEntry{} = entry} =
               Reading.update_reading_list_entry(entry, %{status: :reading})

      assert entry.status == :reading
    end

    test "delete_reading_list_entry/1 deletes the entry" do
      entry = reading_list_entry_fixture()
      assert {:ok, %ReadingListEntry{}} = Reading.delete_reading_list_entry(entry)
      assert_raise Ecto.NoResultsError, fn -> Reading.get_reading_list_entry!(entry.id) end
    end

    test "change_reading_list_entry/1 returns an entry changeset" do
      entry = reading_list_entry_fixture()
      assert %Ecto.Changeset{} = Reading.change_reading_list_entry(entry)
    end
  end

  describe "add_to_reading_list/3" do
    import FunLibrary.LibraryFixtures

    @book_attrs %{
      title: "The Hobbit",
      isbn: "9780261102217",
      external_id: "zyTCAlFPjgYC",
      external_source: "google_books"
    }

    test "finds-or-creates the book and creates a :want_to entry by default" do
      assert {:ok, entry} = Reading.add_to_reading_list(1, @book_attrs)
      assert entry.user_id == 1
      assert entry.status == :want_to
      assert is_nil(entry.finished_at)
    end

    test "reuses the catalog book across users, deduped by isbn" do
      book = book_fixture(isbn: @book_attrs.isbn)

      assert {:ok, entry} = Reading.add_to_reading_list(1, @book_attrs)
      assert entry.book_id == book.id
    end

    test "accepts an explicit status and finished_at for logging an already-read book" do
      assert {:ok, entry} =
               Reading.add_to_reading_list(1, @book_attrs, %{
                 status: :read,
                 finished_at: ~D[2026-01-01]
               })

      assert entry.status == :read
      assert entry.finished_at == ~D[2026-01-01]
    end

    test "rejects adding the same book twice for the same user" do
      {:ok, _entry} = Reading.add_to_reading_list(1, @book_attrs)
      assert {:error, %Ecto.Changeset{}} = Reading.add_to_reading_list(1, @book_attrs)
    end
  end

  describe "reading_sessions" do
    alias FunLibrary.Reading.Session

    import FunLibrary.ReadingFixtures
    import FunLibrary.LibraryFixtures

    test "start_session/2 with valid data creates a session and marks the entry started" do
      entry = reading_list_entry_fixture(status: :want_to)

      assert {:ok, %Session{} = session} =
               Reading.start_session(entry.id, %{
                 "start_page" => 0,
                 "started_at" => ~U[2026-07-18 18:46:00Z]
               })

      assert session.reading_list_entry_id == entry.id
      assert session.start_page == 0
      assert session.started_at == ~U[2026-07-18 18:46:00Z]
      assert is_nil(session.end_page)
      assert is_nil(session.ended_at)

      updated_entry = Reading.get_reading_list_entry!(entry.id)
      assert updated_entry.status == :reading
    end

    test "start_session/2 flips a :stopped entry back to :reading" do
      entry = reading_list_entry_fixture(status: :stopped, started_at: ~D[2026-07-01])

      assert {:ok, _session} =
               Reading.start_session(entry.id, %{
                 "start_page" => 0,
                 "started_at" => ~U[2026-07-18 18:46:00Z]
               })

      updated_entry = Reading.get_reading_list_entry!(entry.id)
      assert updated_entry.status == :reading
    end

    test "start_session/2 flips an :unfinished entry back to :reading" do
      entry = reading_list_entry_fixture(status: :unfinished, started_at: ~D[2026-07-01])

      assert {:ok, _session} =
               Reading.start_session(entry.id, %{
                 "start_page" => 0,
                 "started_at" => ~U[2026-07-18 18:46:00Z]
               })

      updated_entry = Reading.get_reading_list_entry!(entry.id)
      assert updated_entry.status == :reading
    end

    test "start_session/2 does not flip a :read entry back to :reading" do
      entry =
        reading_list_entry_fixture(
          status: :read,
          started_at: ~D[2026-07-01],
          finished_at: ~D[2026-07-15]
        )

      assert {:ok, _session} =
               Reading.start_session(entry.id, %{
                 "start_page" => 0,
                 "started_at" => ~U[2026-07-18 18:46:00Z]
               })

      updated_entry = Reading.get_reading_list_entry!(entry.id)
      assert updated_entry.status == :read
    end

    test "start_session/2 rejects a second open session for the same entry" do
      entry = reading_list_entry_fixture()
      session_fixture(entry.id)

      assert {:error, :session_already_open} =
               Reading.start_session(entry.id, %{
                 "start_page" => 10,
                 "started_at" => ~U[2026-07-19 10:00:00Z]
               })
    end

    test "start_session/2 with invalid data returns error changeset" do
      entry = reading_list_entry_fixture()
      assert {:error, %Ecto.Changeset{}} = Reading.start_session(entry.id, %{})
    end

    test "finish_session/2 with valid data finishes the session" do
      entry = reading_list_entry_fixture(book_id: book_fixture(total_pages: 100).id)
      session = session_fixture(entry.id, %{"start_page" => 0})

      assert {:ok, %Session{} = session} =
               Reading.finish_session(session, %{
                 "end_page" => 30,
                 "ended_at" => ~U[2026-07-18 20:00:00Z]
               })

      assert session.end_page == 30
      assert session.ended_at == ~U[2026-07-18 20:00:00Z]
    end

    test "finish_session/2 marks the entry read when end_page reaches total_pages" do
      entry = reading_list_entry_fixture(book_id: book_fixture(total_pages: 100).id, total_pages: 100)
      session = session_fixture(entry.id, %{"start_page" => 0})

      assert {:ok, _session} =
               Reading.finish_session(session, %{
                 "end_page" => 100,
                 "ended_at" => ~U[2026-07-18 20:00:00Z]
               })

      updated_entry = Reading.get_reading_list_entry!(entry.id)
      assert updated_entry.status == :read
      assert updated_entry.finished_at == Date.utc_today()
    end

    test "finish_session/2 can finish an entry with updated total pages" do
      entry = reading_list_entry_fixture(book_id: book_fixture(total_pages: 100).id, total_pages: 150)
      session = session_fixture(entry.id, %{"start_page" => 0})

      assert {:ok, _session} =
               Reading.finish_session(session, %{
                 "end_page" => 150,
                 "ended_at" => ~U[2026-07-18 20:00:00Z]
               })

      updated_entry = Reading.get_reading_list_entry!(entry.id)
      assert updated_entry.status == :read
      assert updated_entry.finished_at == Date.utc_today()
    end

    test "finish_session/2 rejects end_page lower than start_page" do
      entry = reading_list_entry_fixture()
      session = session_fixture(entry.id, %{"start_page" => 50})

      assert {:error, %Ecto.Changeset{}} =
               Reading.finish_session(session, %{
                 "end_page" => 10,
                 "ended_at" => ~U[2026-07-18 20:00:00Z]
               })
    end

    test "finish_session/2 rejects end_page greater than the book's total_pages" do
      entry = reading_list_entry_fixture(book_id: book_fixture(total_pages: 100).id)
      session = session_fixture(entry.id, %{"start_page" => 0})

      assert {:error, changeset} =
               Reading.finish_session(session, %{
                 "end_page" => 150,
                 "ended_at" => ~U[2026-07-18 20:00:00Z]
               })

      assert "must not exceed the book's total_pages (100)" in errors_on(changeset).end_page
    end

    test "finish_session/2 rejects end_page greater than the book's total_pages of an updated entry" do
      entry = reading_list_entry_fixture(book_id: book_fixture(total_pages: 100).id, total_pages: 150)
      session = session_fixture(entry.id, %{"start_page" => 0})

      assert {:error, changeset} =
               Reading.finish_session(session, %{
                 "end_page" => 160,
                 "ended_at" => ~U[2026-07-18 20:00:00Z]
               })

      assert "must not exceed the book's total_pages (150)" in errors_on(changeset).end_page
    end

    test "get_open_session/1 returns the open session, or nil once finished" do
      entry = reading_list_entry_fixture()
      session = session_fixture(entry.id)

      assert Reading.get_open_session(entry.id).id == session.id

      {:ok, _} =
        Reading.finish_session(session, %{
          "end_page" => 10,
          "ended_at" => ~U[2026-07-18 20:00:00Z]
        })

      assert Reading.get_open_session(entry.id) == nil
    end

    test "delete_session/1 deletes the session" do
      entry = reading_list_entry_fixture()
      session = session_fixture(entry.id)
      assert {:ok, %Session{}} = Reading.delete_session(session)
      assert_raise Ecto.NoResultsError, fn -> Reading.get_session!(session.id) end
    end
  end

  describe "reading_goals" do
    alias FunLibrary.Reading.Goal

    import FunLibrary.ReadingFixtures

    @invalid_attrs %{
      user_id: nil,
      period_type: nil,
      period_start: nil,
      period_end: nil,
      target_books: nil
    }

    test "list_reading_goals/0 returns all reading_goals" do
      goal = goal_fixture()
      assert Reading.list_reading_goals() == [goal]
    end

    test "get_goal!/1 returns the goal with given id" do
      goal = goal_fixture()
      assert Reading.get_goal!(goal.id) == goal
    end

    test "create_goal/1 with valid data creates a goal" do
      valid_attrs = %{
        user_id: 42,
        period_type: :annual,
        period_start: ~D[2026-07-18],
        period_end: ~D[2026-07-18],
        target_books: 42
      }

      assert {:ok, %Goal{} = goal} = Reading.create_goal(valid_attrs)
      assert goal.user_id == 42
      assert goal.period_type == :annual
      assert goal.period_start == ~D[2026-07-18]
      assert goal.period_end == ~D[2026-07-18]
      assert goal.target_books == 42
    end

    test "create_goal/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Reading.create_goal(@invalid_attrs)
    end

    test "update_goal/2 with valid data updates the goal" do
      goal = goal_fixture()

      update_attrs = %{
        user_id: 43,
        period_type: :monthly,
        period_start: ~D[2026-07-19],
        period_end: ~D[2026-07-19],
        target_books: 43
      }

      assert {:ok, %Goal{} = goal} = Reading.update_goal(goal, update_attrs)
      assert goal.user_id == 43
      assert goal.period_type == :monthly
      assert goal.period_start == ~D[2026-07-19]
      assert goal.period_end == ~D[2026-07-19]
      assert goal.target_books == 43
    end

    test "update_goal/2 with invalid data returns error changeset" do
      goal = goal_fixture()
      assert {:error, %Ecto.Changeset{}} = Reading.update_goal(goal, @invalid_attrs)
      assert goal == Reading.get_goal!(goal.id)
    end

    test "delete_goal/1 deletes the goal" do
      goal = goal_fixture()
      assert {:ok, %Goal{}} = Reading.delete_goal(goal)
      assert_raise Ecto.NoResultsError, fn -> Reading.get_goal!(goal.id) end
    end

    test "change_goal/1 returns a goal changeset" do
      goal = goal_fixture()
      assert %Ecto.Changeset{} = Reading.change_goal(goal)
    end
  end
end
