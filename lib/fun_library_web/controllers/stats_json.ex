defmodule FunLibraryWeb.StatsJSON do
  alias FunLibraryWeb.SessionJSON

  def summary(%{stats: stats}) do
    %{data: %{stats | open_session: SessionJSON.open_session(stats.open_session)}}
  end

  def activity(%{activity: activity}) do
    %{data: activity}
  end

  def daily_highlight(%{highlight: highlight}) do
    %{data: highlight}
  end

  def entry(%{stats: stats}) do
    %{data: stats}
  end

  def streak(%{stats: stats}) do
    %{data: stats}
  end
end
