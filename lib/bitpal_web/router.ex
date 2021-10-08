defmodule BitPalWeb.Router do
  use BitPalWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {BitPalWeb.LayoutView, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :doc do
    plug(:browser)
    plug(:put_root_layout, {BitPalWeb.LayoutView, :doc})
  end

  scope "/", BitPalWeb do
    pipe_through(:browser)

    get("/", HomeController, :index)
  end

  scope "/doc", BitPalWeb do
    pipe_through(:doc)

    get("/", DocController, :index)
    get("/toc", DocController, :toc)
    get("/:id", DocController, :show)
  end

  # Server hosted payment UI

  # Admin portal

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Application.get_env(:bitpal, :enable_live_dashboard) do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through(:browser)
      live_dashboard("/dashboard", metrics: BitPalWeb.Telemetry)
    end
  end
end
