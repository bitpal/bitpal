# NOTE add a fallback controller as well?
# https://hexdocs.pm/phoenix/controllers.html#action-fallback

# Possible errors:
# - 400 - Bad Request
#         The request was unacceptable, often due to missing a required parameter.
# - 401 - Unauthorized
#         No valid API key provided.
# - 402 - Request Failed
#         The parameters were valid but the request failed.
# - 403 - Forbidden
#         The API key doesn't have permissions to perform the request.
# - 404 - Not Found
#         The requested resource doesn't exist.
# - 409 - Conflict
#         The request conflicts with another request (perhaps due to using the same idempotent key).
# - 429 - Too Many Requests
#         Too many requests hit the API too quickly.  We recommend an exponential backoff of your requests.
# - 500, 502, 503, 504 - Server Errors
#         Something went wrong on the server.

defmodule BitPalApi.BadRequestError do
  @moduledoc """
  400 - Bad Request, The request was unacceptable, often due to missing a required parameter.
  """
  defexception message: "Bad Request", plug_status: 400
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
  defexception message: "Request failed", plug_status: 402
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
  defexception message: "Custom not found error", plug_status: 404
end
