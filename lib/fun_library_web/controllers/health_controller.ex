defmodule FunLibraryWeb.HealthController do
  use FunLibraryWeb, :controller

  def index(conn, _params) do
    send_resp(conn, 200, "ok")
  end
end
