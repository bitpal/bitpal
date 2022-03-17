defmodule BitPalApi.ErrorView do
  use BitPalApi, :view
  alias Ecto.Changeset
  require Logger

  def render(_, %{reason: error}) when is_struct(error) do
    render_error(error)
  end

  def render_error(error = %BadRequestError{}) do
    %{
      type: "invalid_request_error",
      message: error.message
    }
  end

  def render_error(error = %UnauthorizedError{}) do
    %{
      type: "api_connection_error",
      message: error.message
    }
  end

  def render_error(error = %RequestFailedError{changeset: %Changeset{}}) do
    %{
      type: "invalid_request_error",
      message: error.message,
      errors: render_errors(error.changeset)
    }
  end

  def render_error(error = %RequestFailedError{}) do
    %{
      type: "invalid_request_error",
      message: error.message
    }
    |> put_unless_nil(:code, error.code)
    |> put_unless_nil(:param, error.param)
  end

  def render_error(error = %NotFoundError{param: param}) when is_binary(param) do
    %{
      type: "invalid_request_error",
      code: "resource_missing",
      message: error.message,
      param: param
    }
  end

  def render_error(error = %NotFoundError{}) do
    %{
      type: "invalid_request_error",
      message: error.message
    }
  end

  def render_error(error = %InternalServerError{}) do
    %{
      type: "api_error",
      message: error.message
    }
  end

  def render_error(error) do
    Logger.warn("Missing clause for error: #{inspect(error)}")
    render_error(%InternalServerError{})
  end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    Logger.warn("Missing template for error: #{template}")
    %{message: Phoenix.Controller.status_message_from_template(template)}
  end

  def render_errors(changeset = %Changeset{}) do
    Changeset.traverse_errors(changeset, &render_changeset_error/1)
    # Only keep a single error for each param, to make parsing it easier
    |> Map.new(fn
      {key, []} -> {key, ""}
      {key, [x]} -> {key, x}
    end)
  end

  def render_changeset_error({msg, opts}) when is_binary(msg) and is_list(opts) do
    Enum.reduce(opts, msg, fn {key, val}, acc ->
      String.replace(acc, "%{#{key}}", to_string(val))
    end)
  end
end
