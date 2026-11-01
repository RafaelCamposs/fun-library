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

    test "start_session/2 sets started_at to the session's start day in the app's timezone" do
      entry = reading_list_entry_fixture(status: :want_to)

      # 22:00 at UTC-3 on Jul 18 is already Jul 19 in UTC.
      assert {:ok, _session} =
               Reading.start_session(entry.id, %{
                 "start_page" => 0,
                 "started_at" => ~U[2026-07-19 01:00:00Z]
               })

      assert Reading.get_reading_list_entry!(entry.id).started_at == ~D[2026-07-18]
    end

    test "start_session/2 keeps an existing started_at" do
      entry = reading_list_entry_fixture(status: :stopped, started_at: ~D[2026-07-01])

      assert {:ok, _session} =
               Reading.start_session(entry.id, %{
                 "start_page" => 0,
                 "started_at" => ~U[2026-07-18 18:46:00Z]
               })

      assert Reading.get_reading_list_entry!(entry.id).started_at == ~D[2026-07-01]
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
      %Session{id: open_id} = session_fixture(entry.id)

      assert {:error, {:session_already_open, %Session{id: ^open_id}}} =
               Reading.start_session(entry.id, %{
                 "start_page" => 10,
                 "started_at" => ~U[2026-07-19 10:00:00Z]
               })
    end

    test "start_session/2 rejects a session while the reader has one open on another entry" do
      open_entry = reading_list_entry_fixture(user_id: 7)
      other_entry = reading_list_entry_fixture(user_id: 7)
      %Session{id: open_id} = session_fixture(open_entry.id)

      assert {:error, {:session_already_open, %Session{id: ^open_id}}} =
               Reading.start_session(other_entry.id, %{
                 "start_page" => 0,
                 "started_at" => ~U[2026-07-19 10:00:00Z]
               })

      assert Reading.list_sessions_for_entry(other_entry.id) == []
      assert Reading.get_reading_list_entry!(other_entry.id).status == :want_to
    end

    test "start_session/2 allows a session once the reader's open session is finished" do
      open_entry = reading_list_entry_fixture(user_id: 7)
      other_entry = reading_list_entry_fixture(user_id: 7)
      session = session_fixture(open_entry.id)

      {:ok, _} =
        Reading.finish_session(session, %{
          "end_page" => 10,
          "ended_at" => ~U[2026-07-18 19:30:00Z]
        })

      assert {:ok, %Session{}} =
               Reading.start_session(other_entry.id, %{
                 "start_page" => 0,
                 "started_at" => ~U[2026-07-19 10:00:00Z]
               })
    end

    test "start_session/2 ignores open sessions of other readers" do
      session_fixture(reading_list_entry_fixture(user_id: 7).id)
      entry = reading_list_entry_fixture(user_id: 8)

      assert {:ok, %Session{}} =
               Reading.start_session(entry.id, %{
                 "start_page" => 0,
                 "started_at" => ~U[2026-07-19 10:00:00Z]
               })
    end

    test "get_open_session_for_user/1 returns the reader's open session across entries" do
      entry = reading_list_entry_fixture(user_id: 7)
      reading_list_entry_fixture(user_id: 7)
      assert Reading.get_open_session_for_user(7) == nil

      %Session{id: open_id} = session_fixture(entry.id)

      assert %Session{id: ^open_id} = Reading.get_open_session_for_user(7)
      assert Reading.get_open_session_for_user(8) == nil
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
      entry =
        reading_list_entry_fixture(book_id: book_fixture(total_pages: 100).id, total_pages: 100)

      session = session_fixture(entry.id, %{"start_page" => 0})

      assert {:ok, _session} =
               Reading.finish_session(session, %{
                 "end_page" => 100,
                 "ended_at" => ~U[2026-07-18 20:00:00Z]
               })

      updated_entry = Reading.get_reading_list_entry!(entry.id)
      assert updated_entry.status == :read
      assert updated_entry.finished_at == ~D[2026-07-18]
    end

    test "finish_session/2 can finish an entry with updated total pages" do
      entry =
        reading_list_entry_fixture(book_id: book_fixture(total_pages: 100).id, total_pages: 150)

      session = session_fixture(entry.id, %{"start_page" => 0})

      assert {:ok, _session} =
               Reading.finish_session(session, %{
                 "end_page" => 150,
                 "ended_at" => ~U[2026-07-18 20:00:00Z]
               })

      updated_entry = Reading.get_reading_list_entry!(entry.id)
      assert updated_entry.status == :read
      assert updated_entry.finished_at == ~D[2026-07-18]
    end

    test "finish_session/2 dates a late-evening finish on the app's day, not the UTC day" do
      entry =
        reading_list_entry_fixture(book_id: book_fixture(total_pages: 100).id, total_pages: 100)

      session = session_fixture(entry.id, %{"start_page" => 0})

      # 22:30 at UTC-3 on Jul 18 is already Jul 19 in UTC.
      assert {:ok, _session} =
               Reading.finish_session(session, %{
                 "end_page" => 100,
                 "ended_at" => ~U[2026-07-19 01:30:00Z]
               })

      assert Reading.get_reading_list_entry!(entry.id).finished_at == ~D[2026-07-18]
    end

    test "finish_session/2 dates the entry by the session's end, not when it was logged" do
      entry =
        reading_list_entry_fixture(book_id: book_fixture(total_pages: 100).id, total_pages: 100)

      session = session_fixture(entry.id, %{"start_page" => 0})

      assert {:ok, _session} =
               Reading.finish_session(session, %{
                 "end_page" => 100,
                 "ended_at" => ~U[2026-03-02 15:00:00Z]
               })

      assert Reading.get_reading_list_entry!(entry.id).finished_at == ~D[2026-03-02]
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
      entry =
        reading_list_entry_fixture(book_id: book_fixture(total_pages: 100).id, total_pages: 150)

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

    test "update_session_highlight/2 sets the highlight on a finished session" do
      entry = reading_list_entry_fixture()
      session = session_fixture(entry.id)

      {:ok, session} =
        Reading.finish_session(session, %{
          "end_page" => 10,
          "ended_at" => ~U[2026-07-18 20:00:00Z]
        })

      assert {:ok, %Session{highlight: "A line worth remembering."}} =
               Reading.update_session_highlight(session, %{
                 "highlight" => "A line worth remembering."
               })
    end

    test "update_session_highlight/2 clears the highlight back to nil" do
      entry = reading_list_entry_fixture()
      session = session_fixture(entry.id)

      {:ok, session} =
        Reading.finish_session(session, %{
          "end_page" => 10,
          "ended_at" => ~U[2026-07-18 20:00:00Z]
        })

      {:ok, session} = Reading.update_session_highlight(session, %{"highlight" => "Something"})

      assert {:ok, %Session{highlight: nil}} =
               Reading.update_session_highlight(session, %{"highlight" => nil})
    end

    test "update_session_highlight/2 rejects a highlight over 500 characters" do
      entry = reading_list_entry_fixture()
      session = session_fixture(entry.id)

      {:ok, session} =
        Reading.finish_session(session, %{
          "end_page" => 10,
          "ended_at" => ~U[2026-07-18 20:00:00Z]
        })

      assert {:error, changeset} =
               Reading.update_session_highlight(session, %{
                 "highlight" => String.duplicate("a", 501)
               })

      assert "should be at most 500 character(s)" in errors_on(changeset).highlight
    end

    test "update_session_highlight/2 fails when the session is still open" do
      entry = reading_list_entry_fixture()
      session = session_fixture(entry.id)

      assert {:error, :session_not_finished} =
               Reading.update_session_highlight(session, %{"highlight" => "Too soon"})
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

    @today ~D[2026-11-15]

    test "list_reading_goals/2 lists only the user's goals: current, upcoming, closed, newest period first" do
      dec_2025 = insert_goal!(period_type: :monthly, period_start: ~D[2025-12-01])
      oct_2026 = insert_goal!(period_type: :monthly, period_start: ~D[2026-10-01])
      nov_2026 = insert_goal!(period_type: :monthly, period_start: ~D[2026-11-01])
      year_2027 = insert_goal!(period_type: :annual, period_start: ~D[2027-01-01])
      year_2025 = insert_goal!(period_type: :annual, period_start: ~D[2025-01-01])
      dec_2026 = insert_goal!(period_type: :monthly, period_start: ~D[2026-12-01])
      year_2026 = insert_goal!(period_type: :annual, period_start: ~D[2026-01-01])
      insert_goal!(user_id: 7, period_type: :annual, period_start: ~D[2026-01-01])

      assert Reading.list_reading_goals(42, @today) |> Enum.map(& &1.id) ==
               Enum.map(
                 [year_2026, nov_2026, year_2027, dec_2026, oct_2026, year_2025, dec_2025],
                 & &1.id
               )

      assert Reading.list_reading_goals(8, @today) == []
    end

    test "get_goal!/1 returns the goal with given id" do
      goal = goal_fixture()
      assert Reading.get_goal!(goal.id) == goal
    end

    test "create_goal/3 creates goals for current and upcoming periods" do
      assert {:ok, %Goal{} = goal} =
               Reading.create_goal(
                 42,
                 %{period_type: :monthly, period_start: ~D[2026-11-01], target_books: 2},
                 @today
               )

      assert %{user_id: 42, period_type: :monthly, period_start: ~D[2026-11-01]} = goal
      assert goal.target_books == 2

      assert {:ok, %Goal{}} =
               Reading.create_goal(
                 42,
                 %{
                   "period_type" => "annual",
                   "period_start" => "2027-01-01",
                   "target_books" => 9
                 },
                 @today
               )
    end

    test "create_goal/3 accepts a period on its last day" do
      assert {:ok, %Goal{}} =
               Reading.create_goal(
                 42,
                 %{period_type: :monthly, period_start: ~D[2026-10-01], target_books: 2},
                 ~D[2026-10-31]
               )
    end

    test "create_goal/3 sets user_id programmatically, never from attrs" do
      assert {:ok, %Goal{user_id: 42}} =
               Reading.create_goal(
                 42,
                 %{
                   user_id: 7,
                   period_type: :annual,
                   period_start: ~D[2026-01-01],
                   target_books: 1
                 },
                 @today
               )
    end

    test "create_goal/3 requires period_start to be the first day of the period" do
      for {type, start} <- [
            {:annual, ~D[2027-02-01]},
            {:annual, ~D[2027-01-15]},
            {:monthly, ~D[2026-12-15]}
          ] do
        assert {:error, changeset} =
                 Reading.create_goal(
                   42,
                   %{period_type: type, period_start: start, target_books: 1},
                   @today
                 )

        assert %{period_start: [message]} = errors_on(changeset)
        assert message =~ "must be the first day of a"
      end
    end

    test "create_goal/3 rejects a period that has ended" do
      for {type, start} <- [{:monthly, ~D[2026-10-01]}, {:annual, ~D[2025-01-01]}] do
        assert {:error, changeset} =
                 Reading.create_goal(
                   42,
                   %{period_type: type, period_start: start, target_books: 1},
                   @today
                 )

        assert %{period_start: ["must be a current or upcoming period"]} = errors_on(changeset)
      end
    end

    test "create_goal/3 requires a positive target and all fields" do
      assert {:error, changeset} =
               Reading.create_goal(
                 42,
                 %{period_type: :annual, period_start: ~D[2026-01-01], target_books: 0},
                 @today
               )

      assert %{target_books: ["must be greater than 0"]} = errors_on(changeset)

      assert {:error, changeset} = Reading.create_goal(nil, %{}, @today)

      assert %{
               user_id: ["can't be blank"],
               period_type: ["can't be blank"],
               period_start: ["can't be blank"],
               target_books: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "create_goal/3 allows one goal per type per period per user" do
      attrs = %{period_type: :monthly, period_start: ~D[2027-01-01], target_books: 1}
      assert {:ok, _} = Reading.create_goal(42, attrs, @today)

      assert {:error, changeset} = Reading.create_goal(42, attrs, @today)
      assert %{period_start: ["already has a goal of this type"]} = errors_on(changeset)

      assert {:ok, _} = Reading.create_goal(42, %{attrs | period_type: :annual}, @today)
      assert {:ok, _} = Reading.create_goal(43, attrs, @today)
    end

    test "update_goal/3 changes only the target" do
      goal = insert_goal!(period_type: :monthly, period_start: ~D[2026-11-01], target_books: 2)

      assert {:ok, %Goal{} = updated} =
               Reading.update_goal(
                 goal,
                 %{
                   user_id: 43,
                   period_type: :annual,
                   period_start: ~D[2027-01-01],
                   target_books: 5
                 },
                 @today
               )

      assert %{user_id: 42, period_type: :monthly, period_start: ~D[2026-11-01]} = updated
      assert updated.target_books == 5
    end

    test "update_goal/3 with an invalid target returns an error changeset" do
      goal = insert_goal!(period_type: :annual, period_start: ~D[2027-01-01])

      assert {:error, changeset} = Reading.update_goal(goal, %{target_books: 0}, @today)
      assert %{target_books: ["must be greater than 0"]} = errors_on(changeset)
      assert {:error, %Ecto.Changeset{}} = Reading.update_goal(goal, %{target_books: nil}, @today)
      assert goal == Reading.get_goal!(goal.id)
    end

    test "update_goal/3 and delete_goal/2 refuse a closed goal" do
      goal = insert_goal!(period_type: :monthly, period_start: ~D[2026-10-01], target_books: 4)

      assert {:error, :goal_closed} = Reading.update_goal(goal, %{target_books: 1}, @today)
      assert {:error, :goal_closed} = Reading.delete_goal(goal, @today)
      assert goal == Reading.get_goal!(goal.id)

      # On its last day the goal is still current.
      assert {:ok, %Goal{target_books: 1}} =
               Reading.update_goal(goal, %{target_books: 1}, ~D[2026-10-31])
    end

    test "delete_goal/2 deletes a current or upcoming goal" do
      current = insert_goal!(period_type: :annual, period_start: ~D[2026-01-01])
      upcoming = insert_goal!(period_type: :annual, period_start: ~D[2027-01-01])

      for goal <- [current, upcoming] do
        assert {:ok, %Goal{}} = Reading.delete_goal(goal, @today)
        assert_raise Ecto.NoResultsError, fn -> Reading.get_goal!(goal.id) end
      end
    end
  end
end
