defmodule FunLibraryWeb.ErrorJSON do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on JSON requests.

  See config/config.exs.
  """

  # If you want to customize a particular status code,
  # you may add your own clauses, such as:
  #
  # def render("500.json", _assigns) do
  #   %{errors: %{detail: "Internal Server Error"}}
  # end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  # A refused session start identifies the reader's open session, so the
  # client can say which book to finish first (ADR 0005).
  def render("409.json", %{open_session: open_session}) do
    %{
      errors: %{detail: "Conflict"},
      open_session: FunLibraryWeb.SessionJSON.open_session(open_session)
    }
  end

  # A closed goal is locked (ADR 0006); the reason tells a stale client why.
  def render("409.json", %{reason: :goal_closed}) do
    %{errors: %{detail: "Conflict"}, reason: "goal_closed"}
  end

  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
