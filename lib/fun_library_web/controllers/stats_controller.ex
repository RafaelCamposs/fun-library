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
    render(conn, :streak, stats: Stats.days_streak(String.to_integer(user_id)))
  end
end
