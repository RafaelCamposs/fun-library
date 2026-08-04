defmodule FunLibraryWeb.ReadingListEntryController do
  use FunLibraryWeb, :controller

  alias FunLibrary.Reading
  alias FunLibrary.Reading.ReadingListEntry

  action_fallback FunLibraryWeb.FallbackController

  def index(conn, %{"user_id" => user_id}) do
    entries = Reading.list_reading_list_entries(to_id(user_id))
    render(conn, :index, reading_list_entries: entries)
  end

  @doc """
  Adds a book to a user's reading list: `book` is the (possibly
  user-edited) preview from `BookLookupController.create/2`; `entry` may
  set `status`/`started_at`/`finished_at` (e.g. to log an already-finished
  book).
  """
  def create(conn, %{"user_id" => user_id, "book" => book_attrs} = params) do
    entry_attrs = Map.get(params, "entry", %{})

    with {:ok, %ReadingListEntry{} = entry} <-
           Reading.add_to_reading_list(to_id(user_id), book_attrs, entry_attrs) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/reading_list_entries/#{entry}")
      |> render(:show, reading_list_entry: entry)
    end
  end

  def show(conn, %{"id" => id}) do
    entry = Reading.get_reading_list_entry!(id)
    render(conn, :show, reading_list_entry: entry)
  end

  def update(conn, %{"id" => id, "reading_list_entry" => entry_params}) do
    entry = Reading.get_reading_list_entry!(id)

    with {:ok, %ReadingListEntry{} = entry} <-
           Reading.update_reading_list_entry(entry, entry_params) do
      render(conn, :show, reading_list_entry: entry)
    end
  end

  def delete(conn, %{"id" => id}) do
    entry = Reading.get_reading_list_entry!(id)

    with {:ok, %ReadingListEntry{}} <- Reading.delete_reading_list_entry(entry) do
      send_resp(conn, :no_content, "")
    end
  end

  defp to_id(id) when is_binary(id), do: String.to_integer(id)
  defp to_id(id) when is_integer(id), do: id
end
