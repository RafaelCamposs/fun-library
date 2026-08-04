defmodule FunLibrary.BookLookup.GoogleBooksClient do
  @moduledoc """
  Adapter for the Google Books API `volumes` endpoint. Fetches
  bibliographic data for a single ISBN; persists nothing.
  """

  @base_url "https://www.googleapis.com/books/v1/volumes"

  @doc """
  Fetches book data for a normalized ISBN.

  Returns `{:ok, attrs}` with normalized bibliographic data, or
  `{:error, :not_found | :external_api_error}`.
  """
  def find_by_isbn(isbn) do
    case Req.get(@base_url, params: params(isbn)) do
      {:ok, %Req.Response{status: 200, body: %{"items" => [item | _]}}} ->
        {:ok, normalize(item, isbn)}

      {:ok, %Req.Response{status: 200}} ->
        {:error, :not_found}

      {:ok, %Req.Response{}} ->
        {:error, :external_api_error}

      {:error, _reason} ->
        {:error, :external_api_error}
    end
  end

  defp params(isbn) do
    case Application.get_env(:fun_library, :google_books_api_key) do
      key when is_binary(key) and key != "" -> [q: "isbn:#{isbn}", key: key]
      _ -> [q: "isbn:#{isbn}"]
    end
  end

  defp normalize(%{"id" => id, "volumeInfo" => info}, isbn) do
    %{
      external_id: id,
      external_source: "google_books",
      title: info["title"],
      authors: info["authors"] || [],
      isbn: isbn,
      cover_url: get_in(info, ["imageLinks", "thumbnail"]),
      total_pages: info["pageCount"],
      published_year: published_year(info["publishedDate"])
    }
  end

  defp published_year(nil), do: nil

  defp published_year(published_date) do
    case Integer.parse(published_date) do
      {year, _rest} -> year
      :error -> nil
    end
  end
end
