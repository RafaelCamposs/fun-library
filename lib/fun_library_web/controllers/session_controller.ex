defmodule FunLibraryWeb.SessionController do
  use FunLibraryWeb, :controller

  alias FunLibrary.Reading
  alias FunLibrary.Reading.Session

  action_fallback FunLibraryWeb.FallbackController

  def index(conn, %{"reading_list_entry_id" => entry_id}) do
    reading_sessions = Reading.list_sessions_for_entry(entry_id)
    render(conn, :index, reading_sessions: reading_sessions)
  end

  def create(conn, %{"reading_list_entry_id" => entry_id, "session" => session_params}) do
    with {:ok, %Session{} = session} <- Reading.start_session(entry_id, session_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/reading_sessions/#{session}")
      |> render(:show, session: session)
    end
  end

  def show(conn, %{"id" => id}) do
    session = Reading.get_session!(id)
    render(conn, :show, session: session)
  end

  def finish(conn, %{"id" => id, "session" => session_params}) do
    session = Reading.get_session!(id)

    with {:ok, %Session{} = session} <- Reading.finish_session(session, session_params) do
      render(conn, :show, session: session)
    end
  end

  def delete(conn, %{"id" => id}) do
    session = Reading.get_session!(id)

    with {:ok, %Session{}} <- Reading.delete_session(session) do
      send_resp(conn, :no_content, "")
    end
  end
end
