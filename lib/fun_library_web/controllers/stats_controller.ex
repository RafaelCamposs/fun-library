defmodule FunLibraryWeb.StatsController do
  use FunLibraryWeb, :controller

  alias FunLibrary.Stats

  action_fallback FunLibraryWeb.FallbackController

  def summary(conn, %{"user_id" => user_id}) do
    render(conn, :summary, stats: Stats.summary(String.to_integer(user_id)))
  end

  def entry(conn, %{"id" => id}) do
    render(conn, :entry, stats: Stats.entry_stats(id))
  end

  def streak(conn, %{"user_id" => user_id}) do
    render(conn, :streak, stats: Stats.streak(String.to_integer(user_id)))
  end

  @default_activity_days 84

  def activity(conn, %{"user_id" => user_id} = params) do
    with {:ok, days} <- parse_days(Map.get(params, "days")) do
      render(conn, :activity, activity: Stats.activity(String.to_integer(user_id), days))
    end
  end

  def daily_highlight(conn, %{"user_id" => user_id}) do
    render(conn, :daily_highlight, highlight: Stats.daily_highlight(String.to_integer(user_id)))
  end

  defp parse_days(nil), do: {:ok, @default_activity_days}

  defp parse_days(days) do
    case Integer.parse(days) do
      {days, ""} when days > 0 -> {:ok, days}
      _invalid -> {:error, :bad_request}
    end
  end
end
