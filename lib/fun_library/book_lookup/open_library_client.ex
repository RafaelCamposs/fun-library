defmodule FunLibrary.BookLookup.OpenLibraryClient do
  @moduledoc """
  Adapter for Open Library's `api/books` (bibkeys) endpoint. Fetches
  bibliographic data for a single ISBN; persists nothing.

  Used as a fallback when `GoogleBooksClient` has no match — Open Library's
  catalog covers many regional/foreign-language editions Google Books
  doesn't index, and it has no request quota.
  """

  @base_url "https://openlibrary.org/api/books"

  @doc """
  Fetches book data for a normalized ISBN.

  Returns `{:ok, attrs}` with normalized bibliographic data, or
  `{:error, :not_found | :external_api_error}`.
  """
  def find_by_isbn(isbn) do
    bibkey = "ISBN:#{isbn}"

    case Req.get(@base_url, params: [bibkeys: bibkey, format: "json", jscmd: "data"]) do
      {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
        case Map.get(body, bibkey) do
          nil -> {:error, :not_found}
          data -> {:ok, normalize(data, isbn)}
        end

      {:ok, %Req.Response{}} ->
        {:error, :external_api_error}

      {:error, _reason} ->
        {:error, :external_api_error}
    end
  end

  defp normalize(data, isbn) do
    %{
      external_id: external_id(data),
      external_source: "open_library",
      title: data["title"],
      authors: (data["authors"] || []) |> Enum.map(& &1["name"]),
      isbn: isbn,
      cover_url: get_in(data, ["cover", "medium"]) || get_in(data, ["cover", "large"]),
      total_pages: data["number_of_pages"],
      published_year: published_year(data["publish_date"])
    }
  end

  defp external_id(%{"key" => "/books/" <> id}), do: id
  defp external_id(%{"identifiers" => %{"openlibrary" => [id | _]}}), do: id
  defp external_id(_), do: nil

  defp published_year(nil), do: nil

  defp published_year(publish_date) do
    case Regex.run(~r/\d{4}/, publish_date) do
      [year] -> String.to_integer(year)
      _ -> nil
    end
  end
end
