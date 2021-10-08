defmodule BitPalDoc.Entries do
  use NimblePublisher,
    build: BitPalDoc.Entry,
    from: BitPalDoc.Entry.glob_filenames(),
    as: :entries,
    highlighters: [:makeup_elixir],
    converter: BitPalDoc.Entry.Converter

  def all_entries, do: @entries

  defmodule NotFoundError, do: defexception([:message, plug_status: 404])

  def fetch_entry_by_id(id) do
    Enum.find(all_entries(), &(&1.id == id))
  end

  def get_entry_by_id!(id) do
    fetch_entry_by_id(id) ||
      raise NotFoundError, "entry with id=#{id} not found"
  end
end
