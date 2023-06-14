defmodule BitPal.RPCClient do
  @behaviour BitPal.RPCClientAPI
  require Logger

  @default_headers [{"content-type", "application/json"}]

  @impl true
  def call(url, method, params) do
    http_call(url, method, params)
  end

  # Reimplementation of JSONRPC2.HTTP.call() to -not- throw an error if "jsonrpc" => "2.0"
  # just to support "jsonrpc" "1.0" calls (that don't return the version).
  # Maybe we should have different implementations? I dunno.
  defp http_call(
         url,
         method,
         params,
         headers \\ @default_headers,
         http_method \\ :post,
         hackney_opts \\ [],
         request_id \\ "0"
       ) do
    serializer = Application.get_env(:jsonrpc2, :serializer)

    {:ok, payload} = JSONRPC2.Request.serialized_request({method, params, request_id}, serializer)

    response = :hackney.request(http_method, url, headers, payload, hackney_opts)

    with(
      {:ok, 200, _headers, body_ref} <- response,
      {:ok, body} <- :hackney.body(body_ref),
      {:ok, {_id, result}} <- deserialize_response(body, serializer)
    ) do
      result
    else
      {:ok, status_code, headers, body_ref} ->
        {:error, {:http_request_failed, status_code, headers, :hackney.body(body_ref)}}

      {:ok, status_code, headers} ->
        {:error, {:http_request_failed, status_code, headers}}

      {:error, :econnrefused} ->
        {:error, :econnrefused}

      {:error, reason} ->
        Logger.alert("Request failed #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp deserialize_response(response, serializer) do
    case serializer.decode(response) do
      {:ok, response} -> id_and_response(response)
      {:error, error} -> {:error, error}
      {:error, error, _} -> {:error, error}
    end
  end

  defp id_and_response(%{"id" => id, "result" => result}) do
    {:ok, {id, {:ok, result}}}
  end

  defp id_and_response(%{"id" => id, "error" => error}) do
    {:ok, {id, {:error, {error["code"], error["message"], error["data"]}}}}
  end

  defp id_and_response(response) do
    {:error, {:invalid_response, response}}
  end
end
