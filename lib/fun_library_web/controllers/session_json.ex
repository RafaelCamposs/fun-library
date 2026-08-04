defmodule FunLibraryWeb.SessionJSON do
  alias FunLibrary.Reading.Session

  @doc """
  Renders a list of reading sessions.
  """
  def index(%{reading_sessions: reading_sessions}) do
    %{data: for(session <- reading_sessions, do: data(session))}
  end

  @doc """
  Renders a single session.
  """
  def show(%{session: session}) do
    %{data: data(session)}
  end

  defp data(%Session{} = session) do
    %{
      id: session.id,
      reading_list_entry_id: session.reading_list_entry_id,
      start_page: session.start_page,
      end_page: session.end_page,
      started_at: session.started_at,
      ended_at: session.ended_at
    }
  end
end
