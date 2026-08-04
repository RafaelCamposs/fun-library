defmodule FunLibraryWeb.StatsJSON do
  def summary(%{stats: stats}) do
    %{data: stats}
  end

  def entry(%{stats: stats}) do
    %{data: stats}
  end
end
