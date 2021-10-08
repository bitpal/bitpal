defmodule BitPalDoc.MarkdownTransformation do
  alias BitPalDoc.LinkChecker
  require Logger

  def convert_with(body, opts, postprocess) do
    earmark_opts = Keyword.get(opts, :earmark_options, %Earmark.Options{})
    highlighters = Keyword.get(opts, :highlighters, [])

    body
    |> as_ast!(earmark_opts)
    |> map_structural_transform(postprocess)
    |> ast_to_html!(earmark_opts)
    |> highlight(highlighters)
  end

  defp as_ast!(body, opts) do
    {_status, ast, _messages} = EarmarkParser.as_ast(body, opts)
    ast
  end

  defp ast_to_html!(ast, opts) do
    Earmark.Transform.transform(ast, opts)
  end

  defp highlight(html, []) do
    html
  end

  defp highlight(html, _) do
    NimblePublisher.Highlighter.highlight(html)
  end

  defp map_structural_transform(x, postprocess) when is_list(x) do
    Enum.map(x, fn elem -> map_structural_transform(elem, postprocess) end)
  end

  defp map_structural_transform(x, postprocess) do
    x
    |> postprocess.()
    |> map_process_res(postprocess)
  end

  defp map_process_res({tag, attrs, children, extra}, postprocess) do
    {tag, attrs, map_structural_transform(children, postprocess), extra}
  end

  defp map_process_res(x, _postprocess) when is_binary(x) do
    # Has already been returned, don't process it again
    x
  end

  def demote_headers(val = {"h" <> x, attrs, children, extra}) do
    case Integer.parse(x) do
      {n, ""} ->
        {"h#{n + 1}", attrs, children, extra}

      _ ->
        val
    end
  end

  def demote_headers(val), do: val

  def transform_nonexisting_doc_links(val = {"a", attrs, children, extra}) do
    case List.keyfind(attrs, "href", 0) do
      {"href", url} ->
        if LinkChecker.valid_link?(url) do
          val
        else
          Logger.warn("nonexisting link: #{url}")
          {"span", [{"class", "invalid-link"}], children, extra}
        end

      _ ->
        val
    end
  end

  def transform_nonexisting_doc_links(val), do: val

  def transform_extra_attrs(val) do
    transforms = ["parser"]

    Enum.reduce(transforms, val, fn
      transform, val = {elem, attrs, children, extra} ->
        case List.keytake(attrs, transform, 0) do
          {attr, attrs} ->
            transform({elem, attrs, children, extra}, attr)

          nil ->
            val
        end

      _, val ->
        val
    end)
  end

  def transform(val, {"parser", parser}) do
    parse(val, parser)
  end

  def transform(val, _) do
    val
  end

  def parse({"pre", [{"header", endpoint}], children, extra}, "endpoint") do
    endpoint_link = {"a", [{"name", endpoint_name(endpoint)}], [endpoint], %{}}

    {"aside", [{"class", "endpoint"}],
     [
       {"div", [{"class", "header"}], [endpoint_link], %{}},
       "\n",
       {"pre", [], children, extra}
     ], extra}
  end

  def parse(val, "endpoints") do
    endpoints =
      val
      |> text()
      |> String.split("\n")
      |> Enum.map(fn endpoint ->
        {"li", [], [{"a", [{"href", "#" <> endpoint_name(endpoint)}], [endpoint], %{}}], %{}}
      end)
      |> Enum.intersperse("\n")

    {"aside", [{"class", "endpoints"}],
     [{"div", [{"class", "header"}], ["Endpoints", "\n"], %{}}, {"ul", [], [endpoints], %{}}],
     %{}}
  end

  def parse({tag, attrs, children, extra}, "aside") do
    header = attr_header(attrs)

    if header do
      {"aside", [], [header, {tag, [], children, extra}], %{}}
    else
      {"aside", [], [{tag, [], children, extra}], %{}}
    end
  end

  def parse(val, "http-status-code") do
    content =
      val
      |> text()
      |> String.split("\n")
      |> Enum.map(fn line ->
        [left, right] = String.split(line, ":")

        {"div", [{"class", "row"}],
         [
           {"div", [{"class", "code"}], [String.trim(left)], %{}},
           {"div", [{"class", "descr"}], [String.trim(right)], %{}}
         ], %{}}
      end)

    header = {"div", [{"class", "header"}], ["HTTP Status Codes", "\n"], %{}}

    {"aside", [{"class", "http-status-code"}], [header | content], %{}}
  end

  def parse(val, parser) do
    Logger.error("Unknown markdown attribute parser: #{inspect(parser)} val: #{inspect(val)}")
    val
  end

  defp attr_header([{"header", header}]) do
    {"div", [{"class", "header"}], [header, "\n"], %{}}
  end

  defp attr_header(_), do: nil

  defp endpoint_name(x) do
    Regex.replace(~r/[\s:]/, x, "")
    |> String.downcase()
  end

  def text(val) when is_list(val) do
    val
    |> Enum.map(&text/1)
    |> Enum.join("\n")
  end

  def text({_elem, _attrs, children, _extra}) do
    text(children)
  end

  def text(val) when is_binary(val), do: val
  def text(_), do: ""
end
