defmodule FunLibraryWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use FunLibraryWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: FunLibraryWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: FunLibraryWeb.ErrorHTML, json: FunLibraryWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :bad_request}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: FunLibraryWeb.ErrorJSON)
    |> render(:"400")
  end

  def call(conn, {:error, {:session_already_open, open_session}}) do
    conn
    |> put_status(:conflict)
    |> put_view(json: FunLibraryWeb.ErrorJSON)
    |> render(:"409", open_session: open_session)
  end

  def call(conn, {:error, :goal_closed}) do
    conn
    |> put_status(:conflict)
    |> put_view(json: FunLibraryWeb.ErrorJSON)
    |> render(:"409", reason: :goal_closed)
  end

  def call(conn, {:error, :session_not_finished}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: FunLibraryWeb.ErrorJSON)
    |> render(:"422")
  end

  def call(conn, {:error, :isbn_invalid}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: FunLibraryWeb.ErrorJSON)
    |> render(:"422")
  end

  def call(conn, {:error, :external_api_error}) do
    conn
    |> put_status(:bad_gateway)
    |> put_view(json: FunLibraryWeb.ErrorJSON)
    |> render(:"502")
  end
end
