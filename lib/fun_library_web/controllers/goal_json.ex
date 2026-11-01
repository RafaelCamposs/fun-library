defmodule FunLibraryWeb.GoalJSON do
  alias FunLibrary.Reading.Goal

  @doc """
  Renders a list of goals, each with its derived progress.
  """
  def index(%{goals: goals}) do
    %{data: for(goal <- goals, do: data(goal))}
  end

  @doc """
  Renders a single goal with its derived progress.
  """
  def show(%{goal: goal}) do
    %{data: data(goal)}
  end

  @doc """
  Renders a single goal with its progress and the books it covers.
  """
  def detail(%{goal: goal, books: %{finished: finished, also_read: also_read}}) do
    %{data: Map.merge(data(goal), %{finished: finished, also_read: also_read})}
  end

  defp data({%Goal{} = goal, progress}) do
    %{
      id: goal.id,
      user_id: goal.user_id,
      period_type: goal.period_type,
      period_start: goal.period_start,
      period_end: progress.period_end,
      target_books: goal.target_books,
      state: progress.state,
      books_finished: progress.books_finished,
      outcome: progress.outcome
    }
  end
end
