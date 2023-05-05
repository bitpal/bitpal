defmodule BitPalWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use BitPalWeb, :controller
      use BitPalWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(js css fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: BitPalWeb.Layouts]

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {BitPalWeb.Layouts, :app}

      unquote(html_helpers())
      unquote(standard_components())

      alias BitPal.Repo
      alias BitPalWeb.Breadcrumbs
      require Logger
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
      unquote(standard_components())
    end
  end

  def live_auth do
    quote do
      import Phoenix.Component
      import Phoenix.LiveView

      unquote(html_helpers())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: BitPalWeb.Endpoint,
        router: BitPalWeb.Router,
        statics: BitPalWeb.static_paths()
    end
  end

  def component do
    quote do
      use Phoenix.Component

      unquote(html_helpers())
    end
  end

  defp standard_components do
    quote do
      # Note that we can't import components in html_helpers as that introduces
      # a cyclic dependency loop.
      import BitPalWeb.PortalComponents
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import Phoenix.HTML.Form
      import Phoenix.HTML.Link

      import Phoenix.LiveView.Helpers
      alias Phoenix.LiveView.JS

      import BitPalWeb.ErrorHelpers
      import BitPal.RenderHelpers
      import BitPalWeb.HTMLHelpers

      unquote(verified_routes())
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
