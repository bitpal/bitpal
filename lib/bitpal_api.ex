defmodule BitPalApi do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use BitPalApi, :controller
      use BitPalApi, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: BitPalApi

      import Plug.Conn
      alias BitPalApi.ErrorView
      alias BitPalApi.Router.Helpers, as: Routes

      unquote(errors())
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/bitpal_api/templates",
        namespace: BitPalApi

      unquote(view_helpers())
      unquote(errors())
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import Phoenix.View
      import BitPalApi.ChannelHelpers
      alias BitPalApi.InvoiceView

      unquote(errors())
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import BitPal.ViewHelpers

      alias BitPalApi.Router.Helpers, as: Routes
    end
  end

  defp errors do
    quote do
      alias BitPalApi.BadRequestError
      alias BitPalApi.ForbiddenError
      alias BitPalApi.InternalServerError
      alias BitPalApi.NotFoundError
      alias BitPalApi.RequestFailedError
      alias BitPalApi.UnauthorizedError
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
