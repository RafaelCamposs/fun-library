defmodule FunLibraryWeb.GoalController do
  use FunLibraryWeb, :controller

  alias FunLibrary.{AppTime, Reading, Stats}
  alias FunLibrary.Reading.Goal

  action_fallback FunLibraryWeb.FallbackController

  def index(conn, %{"user_id" => user_id}) do
    today = AppTime.today()

    goals =
      user_id
      |> to_id()
      |> Reading.list_reading_goals(today)
      |> Enum.map(&with_progress(&1, today))

    render(conn, :index, goals: goals)
  end

  def create(conn, %{"goal" => goal_params}) do
    {user_id, attrs} = Map.pop(goal_params, "user_id")

    with {:ok, %Goal{} = goal} <- Reading.create_goal(to_id(user_id), attrs) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/reading_goals/#{goal}")
      |> render(:show, goal: with_progress(goal, AppTime.today()))
    end
  end

  def show(conn, %{"id" => id}) do
    goal = Reading.get_goal!(id)

    render(conn, :detail,
      goal: with_progress(goal, AppTime.today()),
      books: Stats.goal_books(goal)
    )
  end

  def update(conn, %{"id" => id, "goal" => goal_params}) do
    goal = Reading.get_goal!(id)
    today = AppTime.today()

    with {:ok, %Goal{} = goal} <- Reading.update_goal(goal, goal_params, today) do
      render(conn, :show, goal: with_progress(goal, today))
    end
  end

  def delete(conn, %{"id" => id}) do
    goal = Reading.get_goal!(id)

    with {:ok, %Goal{}} <- Reading.delete_goal(goal) do
      send_resp(conn, :no_content, "")
    end
  end

  defp with_progress(%Goal{} = goal, today), do: {goal, Stats.goal_progress(goal, today)}

  # A missing or non-numeric user id is left for the changeset to reject.
  defp to_id(id) when is_integer(id), do: id

  defp to_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp to_id(_id), do: nil
end
