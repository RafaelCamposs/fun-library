defmodule FunLibraryWeb.GoalControllerTest do
  use FunLibraryWeb.ConnCase

  import FunLibrary.ReadingFixtures
  alias FunLibrary.{AppTime, Reading}

  setup %{conn: conn} do
    today = AppTime.today()

    {:ok,
     conn: put_req_header(conn, "accept", "application/json"),
     today: today,
     this_year: Date.new!(today.year, 1, 1),
     next_month: today |> Date.end_of_month() |> Date.add(1),
     last_year: Date.new!(today.year - 1, 1, 1)}
  end

  describe "index" do
    test "lists the user's goals with their derived state, current first", %{conn: conn} = ctx do
      closed = insert_goal!(user_id: 1, period_start: ctx.last_year, target_books: 1)
      current = goal_fixture(user_id: 1, period_start: ctx.this_year, target_books: 3)
      upcoming = goal_fixture(user_id: 1, period_type: :monthly, period_start: ctx.next_month)
      goal_fixture(user_id: 2, period_start: ctx.this_year)

      reading_list_entry_fixture(
        user_id: 1,
        status: :read,
        finished_at: Date.new!(ctx.today.year - 1, 6, 1)
      )

      conn = get(conn, ~p"/api/reading_goals?user_id=1")

      assert [current_json, upcoming_json, closed_json] = json_response(conn, 200)["data"]

      assert current_json == %{
               "id" => current.id,
               "user_id" => 1,
               "period_type" => "annual",
               "period_start" => Date.to_iso8601(ctx.this_year),
               "period_end" => "#{ctx.today.year}-12-31",
               "target_books" => 3,
               "state" => "current",
               "books_finished" => 0,
               "outcome" => nil
             }

      assert %{"id" => upcoming_id, "state" => "upcoming", "outcome" => nil} = upcoming_json
      assert upcoming_id == upcoming.id

      assert %{"id" => closed_id, "state" => "closed", "books_finished" => 1} = closed_json
      assert %{"outcome" => "achieved"} = closed_json
      assert closed_id == closed.id
    end

    test "is empty for a user without goals", %{conn: conn} do
      conn = get(conn, ~p"/api/reading_goals?user_id=99")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "show" do
    test "renders the goal with its finished and also-read books", %{conn: conn} = ctx do
      goal = goal_fixture(user_id: 1, period_start: ctx.this_year, target_books: 2)

      finished =
        reading_list_entry_fixture(user_id: 1, status: :read, finished_at: ctx.this_year)

      also_read = reading_list_entry_fixture(user_id: 1)
      session = session_fixture(also_read.id, %{"started_at" => local_noon(ctx.this_year)})

      {:ok, _} =
        Reading.finish_session(session, %{
          "end_page" => 10,
          "ended_at" => DateTime.add(local_noon(ctx.this_year), 1, :hour)
        })

      conn = get(conn, ~p"/api/reading_goals/#{goal}")
      data = json_response(conn, 200)["data"]

      assert %{"state" => "current", "books_finished" => 1, "target_books" => 2} = data

      assert data["finished"] == [
               %{
                 "entry_id" => finished.id,
                 "book_id" => finished.book_id,
                 "title" => finished.book.title,
                 "cover_url" => finished.book.cover_url,
                 "finished_at" => Date.to_iso8601(ctx.this_year)
               }
             ]

      assert data["also_read"] == [
               %{
                 "entry_id" => also_read.id,
                 "book_id" => also_read.book_id,
                 "title" => also_read.book.title,
                 "cover_url" => also_read.book.cover_url,
                 "label" => "reading",
                 "last_reading_day" => Date.to_iso8601(ctx.this_year)
               }
             ]
    end

    test "404s for an unknown goal", %{conn: conn} do
      assert_error_sent 404, fn -> get(conn, ~p"/api/reading_goals/0") end
    end
  end

  describe "create goal" do
    test "renders the goal when data is valid", %{conn: conn} = ctx do
      conn =
        post(conn, ~p"/api/reading_goals",
          goal: %{
            user_id: 1,
            period_type: "monthly",
            period_start: Date.to_iso8601(ctx.next_month),
            target_books: 3
          }
        )

      assert %{"id" => id} = data = json_response(conn, 201)["data"]

      assert %{
               "user_id" => 1,
               "period_type" => "monthly",
               "target_books" => 3,
               "state" => "upcoming",
               "books_finished" => 0,
               "outcome" => nil
             } = data

      assert data["period_end"] == Date.to_iso8601(Date.end_of_month(ctx.next_month))
      assert Reading.get_goal!(id).user_id == 1
    end

    test "renders 422 for a duplicate, past or misaligned period", %{conn: conn} = ctx do
      goal_fixture(user_id: 1, period_start: ctx.this_year)

      for {type, start} <- [
            {"annual", ctx.this_year},
            {"annual", ctx.last_year},
            {"monthly", Date.add(ctx.next_month, 1)}
          ] do
        conn =
          post(conn, ~p"/api/reading_goals",
            goal: %{
              user_id: 1,
              period_type: type,
              period_start: Date.to_iso8601(start),
              target_books: 3
            }
          )

        assert %{"period_start" => [_]} = json_response(conn, 422)["errors"]
      end
    end

    test "renders 422 when data is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/reading_goals", goal: %{period_type: nil})

      assert %{"user_id" => _, "period_type" => _, "period_start" => _, "target_books" => _} =
               json_response(conn, 422)["errors"]
    end
  end

  describe "update goal" do
    test "changes only the target", %{conn: conn} = ctx do
      goal = goal_fixture(user_id: 1, period_start: ctx.this_year, target_books: 3)

      conn =
        put(conn, ~p"/api/reading_goals/#{goal}",
          goal: %{
            target_books: 5,
            user_id: 2,
            period_type: "monthly",
            period_start: Date.to_iso8601(ctx.next_month)
          }
        )

      assert %{
               "id" => id,
               "target_books" => 5,
               "user_id" => 1,
               "period_type" => "annual",
               "state" => "current"
             } = json_response(conn, 200)["data"]

      assert id == goal.id
      assert Reading.get_goal!(goal.id).period_start == ctx.this_year
    end

    test "renders 422 for an invalid target", %{conn: conn} = ctx do
      goal = goal_fixture(user_id: 1, period_start: ctx.this_year)

      conn = put(conn, ~p"/api/reading_goals/#{goal}", goal: %{target_books: 0})
      assert %{"target_books" => [_]} = json_response(conn, 422)["errors"]
    end

    test "renders 409 for a closed goal", %{conn: conn} = ctx do
      goal = insert_goal!(user_id: 1, period_start: ctx.last_year, target_books: 3)

      conn = put(conn, ~p"/api/reading_goals/#{goal}", goal: %{target_books: 1})

      assert json_response(conn, 409) == %{
               "errors" => %{"detail" => "Conflict"},
               "reason" => "goal_closed"
             }

      assert Reading.get_goal!(goal.id).target_books == 3
    end
  end

  describe "delete goal" do
    test "deletes an unclosed goal", %{conn: conn} = ctx do
      goal = goal_fixture(user_id: 1, period_type: :monthly, period_start: ctx.next_month)

      conn = delete(conn, ~p"/api/reading_goals/#{goal}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/reading_goals/#{goal}")
      end
    end

    test "renders 409 for a closed goal", %{conn: conn} = ctx do
      goal = insert_goal!(user_id: 1, period_start: ctx.last_year)

      conn = delete(conn, ~p"/api/reading_goals/#{goal}")

      assert json_response(conn, 409) == %{
               "errors" => %{"detail" => "Conflict"},
               "reason" => "goal_closed"
             }

      assert Reading.get_goal!(goal.id)
    end
  end

  # Noon on `date` in the app's timezone, as a UTC datetime.
  defp local_noon(date) do
    DateTime.new!(date, ~T[12:00:00])
    |> DateTime.add(-Application.fetch_env!(:fun_library, :utc_offset_minutes), :minute)
  end
end
