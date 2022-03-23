# NOTE add a fallback controller as well?
# https://hexdocs.pm/phoenix/controllers.html#action-fallback

defmodule BitPalApi.BadRequestError do
  @moduledoc """
  400 - Bad Request, The request was unacceptable, often due to missing a required parameter.
  """
  defexception message: "Bad Request", plug_status: 400, changeset: nil, code: nil
end

defmodule BitPalApi.UnauthorizedError do
  @moduledoc """
  401 - Unauthorized, No valid API key provided.
  """
  defexception message: "Unauthorized", plug_status: 401
end

defmodule BitPalApi.RequestFailedError do
  @moduledoc """
  402 - Request Failed, The parameters were valid but the request failed.
  """
  defexception message: "Request Failed", plug_status: 402, changeset: nil, code: nil, param: nil
end

defmodule BitPalApi.ForbiddenError do
  @moduledoc """
  403 - Forbidden, The API key doesn't have permissions to perform the request.
  """
  defexception message: "Forbidden", plug_status: 403
end

defmodule BitPalApi.NotFoundError do
  @moduledoc """
  404 - Not Found, The requested resource doesn't exist.
  """
  defexception message: "Not Found", plug_status: 404, param: nil
end

defmodule BitPalApi.InternalServerError do
  @moduledoc """
  500 - Internal Server Error.
  """
  defexception message: "Internal Server Error", plug_status: 500
end
