# NOTE add a fallback controller as well?
# https://hexdocs.pm/phoenix/controllers.html#action-fallback

defmodule BitPalApi.Errors do
  defmacro __using__(_) do
    quote do
      alias BitPalApi.BadRequestError
      alias BitPalApi.ForbiddenError
      alias BitPalApi.InternalServerError
      alias BitPalApi.NotFoundError
      alias BitPalApi.RequestFailedError
      alias BitPalApi.UnauthorizedError
    end
  end
end

# FIXME
# These error codes are quite bad. They're taken from Stripe's API,
# but they don't correspond to HTTP status codes...
#
# Instead rework status codes:
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Status
#
# Should use:
# Not errors:
# 200 OK
# 201 Created
# 202 Accepted
# 204 No Content
# 205 Reset Content
#
# Redirects:
# 301 Moved Permanently
# 302 Found
# 304 Not Modified
#
# Errors:
# 400 Bad Request
# 401 Unauthorized
# 403 Forbidden
# 404 Not Found
# 405 Method Not Allowed
# 408 Request Timeout
# 409 Conflict
# 410 Gone
# 429 Too Many Requests
#
# 500 Internal Server Error
# 501 Not Implemented
# 503 Service Unavailable
#    If a backend isn't ready for instance

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
