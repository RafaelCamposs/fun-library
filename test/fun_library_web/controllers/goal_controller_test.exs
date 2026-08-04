defmodule FunLibraryWeb.GoalControllerTest do
  use FunLibraryWeb.ConnCase

  import FunLibrary.ReadingFixtures
  alias FunLibrary.Reading.Goal

  @create_attrs %{
    user_id: 42,
    period_type: :annual,
    period_start: ~D[2026-07-18],
    period_end: ~D[2026-07-18],
    target_books: 42
  }
  @update_attrs %{
    user_id: 43,
    period_type: :monthly,
    period_start: ~D[2026-07-19],
    period_end: ~D[2026-07-19],
    target_books: 43
  }
  @invalid_attrs %{
    user_id: nil,
    period_type: nil,
    period_start: nil,
    period_end: nil,
    target_books: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all reading_goals", %{conn: conn} do
      conn = get(conn, ~p"/api/reading_goals")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create goal" do
    test "renders goal when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/reading_goals", goal: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/reading_goals/#{id}")

      assert %{
               "id" => ^id,
               "period_end" => "2026-07-18",
               "period_start" => "2026-07-18",
               "period_type" => "annual",
               "target_books" => 42,
               "user_id" => 42
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/reading_goals", goal: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update goal" do
    setup [:create_goal]

    test "renders goal when data is valid", %{conn: conn, goal: %Goal{id: id} = goal} do
      conn = put(conn, ~p"/api/reading_goals/#{goal}", goal: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/reading_goals/#{id}")

      assert %{
               "id" => ^id,
               "period_end" => "2026-07-19",
               "period_start" => "2026-07-19",
               "period_type" => "monthly",
               "target_books" => 43,
               "user_id" => 43
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, goal: goal} do
      conn = put(conn, ~p"/api/reading_goals/#{goal}", goal: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete goal" do
    setup [:create_goal]

    test "deletes chosen goal", %{conn: conn, goal: goal} do
      conn = delete(conn, ~p"/api/reading_goals/#{goal}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/reading_goals/#{goal}")
      end
    end
  end

  defp create_goal(_) do
    goal = goal_fixture()

    %{goal: goal}
  end
end
