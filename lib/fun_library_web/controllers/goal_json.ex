defmodule FunLibraryWeb.GoalJSON do
  alias FunLibrary.Reading.Goal

  @doc """
  Renders a list of reading_goals.
  """
  def index(%{reading_goals: reading_goals}) do
    %{data: for(goal <- reading_goals, do: data(goal))}
  end

  @doc """
  Renders a single goal.
  """
  def show(%{goal: goal}) do
    %{data: data(goal)}
  end

  defp data(%Goal{} = goal) do
    %{
      id: goal.id,
      user_id: goal.user_id,
      period_type: goal.period_type,
      period_start: goal.period_start,
      period_end: goal.period_end,
      target_books: goal.target_books
    }
  end
end
