defmodule FunLibraryWeb.BookLookupJSON do
  @doc """
  Renders a book lookup preview.
  """
  def show(%{book: attrs}) do
    %{data: attrs}
  end
end
