defmodule BitPalDoc.MarkdownTransformationTest do
  use ExUnit.Case, async: true
  import BitPalDoc.MarkdownTransformation

  defp process(input, fun) do
    convert_with(input, [], fun)
  end

  defp process_text(input) do
    {:ok, ast, _} = EarmarkParser.as_ast(input)
    text(ast)
  end

  test "demote headers" do
    assert process("# One\n## Two", &demote_headers/1) ==
             ~s{<h2>\nOne</h2>\n<h3>\nTwo</h3>\n}
  end

  test "nonexisting doc links" do
    # Existing
    assert process("[text](/doc/configuration)", &transform_nonexisting_doc_links/1) =~
             ~s{<a href="/doc/configuration">text</a>}

    # Nonexisting
    assert process("[text](/doc/xyxyxy)", &transform_nonexisting_doc_links/1) =~
             ~s{<span class="invalid-link">\ntext  </span>}
  end

  test "transform endpoint marker" do
    input = """
    ~~~sh
    $ curl
    ~~~
    {: parser="endpoint" header="GET /v1/invoices/:id"}
    """

    assert process(input, &transform_extra_attrs/1) =~
             """
             <aside class="endpoint">
               <div class="header">
             <a name="get/v1/invoices/id">GET /v1/invoices/:id</a>  </div>

               <pre><code class="sh">$ curl</code></pre>
             </aside>
             """
  end

  test "transform endpoints marker" do
    input = """
    ~~~
    POST /v1/invoices
    GET /v1/invoices/:id
    ~~~
    {: parser="endpoints"}
    """

    assert process(input, &transform_extra_attrs/1) =~
             """
             <aside class="endpoints">
               <div class="header">
             Endpoints
               </div>
               <ul>
                 <li>
             <a href="#post/v1/invoices">POST /v1/invoices</a>    </li>

                 <li>
             <a href="#get/v1/invoices/id">GET /v1/invoices/:id</a>    </li>
               </ul>
             </aside>
             """
  end

  test "text" do
    assert process_text("[text](/some/link)") == "text"
    assert process_text("# One\n## Two") == "One\nTwo"

    input = """
    ~~~
    POST /v1/invoices
    GET /v1/invoices/:id
    ~~~
    """

    assert process_text(input) == "POST /v1/invoices\nGET /v1/invoices/:id"
  end
end
