defmodule BitPalDoc.LinkChecker do
  @doc """
  Check if links are valid.
  """

  # It exists both here and in BitPalDoc.Entries because we do link transformation
  # in compile time, and @entries doesn't exist yet as the module hasn't finished compiling yet.
  # This is an ugly workaround.
  @entry_ids BitPalDoc.Entry.glob_filenames()
             |> Path.wildcard()
             |> then(fn xs ->
               [
                 # Extra routes as defined in BitPalWeb.Router
                 # Would be nice to be able to check it programmatically
                 "toc"
                 | Enum.map(xs, &BitPalDoc.Entry.filename2id/1)
               ]
             end)
             |> MapSet.new()

  def valid_link?("/"), do: true
  def valid_link?("#" <> _), do: true
  def valid_link?("/doc"), do: true
  def valid_link?("/doc/" <> path), do: has_entry?(path)
  def valid_link?("http" <> _url), do: true
  def valid_link?(_), do: false

  def has_entry?(id) do
    MapSet.member?(@entry_ids, id)
  end
end
