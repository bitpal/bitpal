defmodule BitPalDoc.Entry do
  import BitPalDoc.MarkdownTransformation

  @enforce_keys [:id, :title, :body]
  defstruct [:id, :title, :body]

  def build(filename, attrs, body) do
    struct!(__MODULE__, [id: filename2id(filename), body: body] ++ Map.to_list(attrs))
  end

  def filename2id(filename) do
    filename
    |> Path.rootname()
    |> String.split("server_docs/")
    |> List.last()
  end

  def glob_filenames, do: Application.app_dir(:bitpal, "priv/server_docs/**.md")

  defmodule Converter do
    def convert(_ext, body, opts) do
      convert_with(body, opts, fn x ->
        x
        |> demote_headers()
        |> transform_nonexisting_doc_links()
        |> transform_extra_attrs()
      end)
    end
  end
end
