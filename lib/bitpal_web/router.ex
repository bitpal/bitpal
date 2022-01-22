defmodule BitPalWeb.Router do
  use BitPalWeb, :router

  import BitPalWeb.UserAuth
  import BitPalWeb.ServerSetup
  import Phoenix.LiveDashboard.Router
  alias BitPalWeb.InvoiceLiveAuth
  alias BitPalWeb.StoreLiveAuth
  alias BitPalWeb.UserLiveAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {BitPalWeb.LayoutView, :portal})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_user)
  end

  pipeline :doc_layout do
    plug(:put_root_layout, {BitPalWeb.LayoutView, :doc})
  end

  pipeline :portal do
    plug(:browser)
    plug(:redirect_unless_server_setup)
  end

  pipeline :authenticated_portal do
    plug(:portal)
    plug(:require_authenticated_user)
  end

  pipeline :setup_wizard do
    plug(:browser)
    plug(:put_root_layout, {BitPalWeb.LayoutView, :setup_wizard})
  end

  # Main portal

  live_session :dashboard, on_mount: UserLiveAuth do
    scope "/", BitPalWeb do
      pipe_through([:authenticated_portal])

      live("/", HomeLive, :dashboard)
    end
  end

  live_session :invoices, on_mount: [UserLiveAuth, InvoiceLiveAuth] do
    scope "/", BitPalWeb do
      pipe_through([:authenticated_portal])

      live("/invoices/:id", InvoiceLive, :show)
    end
  end

  live_session :stores, on_mount: [UserLiveAuth, StoreLiveAuth] do
    scope "/", BitPalWeb do
      pipe_through([:authenticated_portal])

      # Shoold be /stores/:slug/invoices, but we need a live redirect
      live("/stores/:slug", StoreLive, :show)
      live("/stores/:slug/addresses", StoreAddressesLive, :show)
      live("/stores/:slug/transactions", StoreTransactionsLive, :show)
      live("/stores/:slug/settings", StoreSettingsLive, :show)
    end
  end

  # Admin and server management

  live_session :server, on_mount: UserLiveAuth do
    scope "/", BitPalWeb do
      pipe_through([:authenticated_portal])

      live("/server/backends", ServerBackendsLive, :index)
      live("/server/backends/:backend", ServerBackendLive, :show)

      live("/server/settings", ServerSettingsLive, :show)
    end
  end

  scope "/", BitPalWeb do
    pipe_through([:authenticated_portal])

    live_dashboard("/server/dashboard", metrics: BitPalWeb.Telemetry)
  end

  # Setup routes
  scope "/", BitPalWeb do
    pipe_through([:setup_wizard, :redirect_if_server_admin_created])

    get("/server/setup/server_admin", ServerSetupAdminController, :show)
    post("/server/setup/server_admin", ServerSetupAdminController, :create)
  end

  live_session :setup, on_mount: UserLiveAuth do
    scope "/", BitPalWeb do
      # NOTE: This should only allow server admin when that concept has been created
      pipe_through([:setup_wizard, :redirect_unless_server_setup, :require_authenticated_user])

      live("/server/setup/wizard", ServerSetupLive, :wizard)
    end
  end

  # Authentication routes

  scope "/", BitPalWeb do
    pipe_through([:portal, :redirect_if_user_is_authenticated])

    # Add these back later when we can invite people
    get("/users/register", UserRegistrationController, :new)
    post("/users/register", UserRegistrationController, :create)
  end

  scope "/", BitPalWeb do
    pipe_through([:browser, :redirect_unless_server_setup, :redirect_if_user_is_authenticated])

    get("/users/log_in", UserSessionController, :new)
    post("/users/log_in", UserSessionController, :create)
    get("/users/reset_password", UserResetPasswordController, :new)
    post("/users/reset_password", UserResetPasswordController, :create)
    get("/users/reset_password/:token", UserResetPasswordController, :edit)
    put("/users/reset_password/:token", UserResetPasswordController, :update)
  end

  scope "/", BitPalWeb do
    pipe_through([:authenticated_portal])

    get("/users/settings", UserSettingsController, :edit)
    put("/users/settings", UserSettingsController, :update)
    get("/users/settings/confirm_email/:token", UserSettingsController, :confirm_email)
  end

  scope "/", BitPalWeb do
    pipe_through([:browser])

    delete("/users/log_out", UserSessionController, :delete)
    get("/users/confirm", UserConfirmationController, :new)
    post("/users/confirm", UserConfirmationController, :create)
    get("/users/confirm/:token", UserConfirmationController, :edit)
    post("/users/confirm/:token", UserConfirmationController, :update)
  end

  # Documentation

  scope "/doc", BitPalWeb do
    pipe_through([:browser, :doc_layout])

    get("/", DocController, :index)
    get("/toc", DocController, :toc)
    get("/:id", DocController, :show)
  end
end
