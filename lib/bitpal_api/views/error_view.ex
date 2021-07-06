defmodule BitPalApi.ErrorView do
  use BitPalApi, :view

  def render("error.json", %{changeset: changeset}) do
    %{errors: changeset}
  end

  def render("error.json", %{error: :bad_request}) do
    %{reason: "Bad Request"}
  end

  def render("error.json", %{error: :unauthorized}) do
    %{reason: "Unauthorized"}
  end

  def render("error.json", %{error: :request_failed}) do
    %{reason: "Request Failed"}
  end

  def render("error.json", %{error: _error}) do
    %{reason: "Internal Server Error"}
  end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
