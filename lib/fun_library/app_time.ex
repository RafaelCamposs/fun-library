defmodule FunLibrary.AppTime do
  @moduledoc """
  The app's calendar: a fixed UTC offset (`:utc_offset_minutes`) that
  defines which calendar day an instant belongs to, for reading days,
  entry start/finish dates and stats.
  """

  @doc """
  Returns today's date in the app's timezone.
  """
  def today, do: local_date(DateTime.utc_now())

  @doc """
  Returns the calendar date of a UTC datetime in the app's timezone.
  """
  def local_date(%DateTime{} = datetime) do
    datetime
    |> DateTime.add(Application.fetch_env!(:fun_library, :utc_offset_minutes), :minute)
    |> DateTime.to_date()
  end
end
