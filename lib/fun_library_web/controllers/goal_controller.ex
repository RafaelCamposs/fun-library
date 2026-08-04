defmodule FunLibraryWeb.GoalController do
  use FunLibraryWeb, :controller

  alias FunLibrary.Reading
  alias FunLibrary.Reading.Goal

  action_fallback FunLibraryWeb.FallbackController

  def index(conn, _params) do
    reading_goals = Reading.list_reading_goals()
    render(conn, :index, reading_goals: reading_goals)
  end

  def create(conn, %{"goal" => goal_params}) do
    with {:ok, %Goal{} = goal} <- Reading.create_goal(goal_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/reading_goals/#{goal}")
      |> render(:show, goal: goal)
    end
  end

  def show(conn, %{"id" => id}) do
    goal = Reading.get_goal!(id)
    render(conn, :show, goal: goal)
  end

  def update(conn, %{"id" => id, "goal" => goal_params}) do
    goal = Reading.get_goal!(id)

    with {:ok, %Goal{} = goal} <- Reading.update_goal(goal, goal_params) do
      render(conn, :show, goal: goal)
    end
  end

  def delete(conn, %{"id" => id}) do
    goal = Reading.get_goal!(id)

    with {:ok, %Goal{}} <- Reading.delete_goal(goal) do
      send_resp(conn, :no_content, "")
    end
  end
end
