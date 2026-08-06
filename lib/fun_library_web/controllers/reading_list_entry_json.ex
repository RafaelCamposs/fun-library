defmodule FunLibraryWeb.ReadingListEntryJSON do
  alias FunLibrary.Reading.ReadingListEntry

  @doc """
  Renders a list of reading list entries.
  """
  def index(%{reading_list_entries: entries}) do
    %{data: for(entry <- entries, do: data(entry))}
  end

  @doc """
  Renders a single reading list entry.
  """
  def show(%{reading_list_entry: entry}) do
    %{data: data(entry)}
  end

  defp data(%ReadingListEntry{} = entry) do
    %{
      id: entry.id,
      user_id: entry.user_id,
      book_id: entry.book_id,
      status: entry.status,
      started_at: entry.started_at,
      finished_at: entry.finished_at,
      total_pages: entry.total_pages,
      effective_total_pages: entry.total_pages || entry.book.total_pages
    }
  end
end
