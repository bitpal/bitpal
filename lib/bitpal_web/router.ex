defmodule BitPalWeb.Router do
  use BitPalWeb, :router

  import BitPalWeb.UserAuth
  import BitPalWeb.ServerSetup
  import Phoenix.LiveDashboard.Router
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

  live_session :portal, on_mount: UserLiveAuth do
    scope "/", BitPalWeb do
      pipe_through([:authenticated_portal])

      live("/", DashboardLive, :show)

      live("/invoices/:id", InvoiceLive, :show)

      live("/stores", CreateStoreLive, :show)

      live("/stores/:store", StoreInvoicesLive, :redirect)
      live("/stores/:store/invoices", StoreInvoicesLive, :show)
      live("/stores/:store/addresses", StoreAddressesLive, :show)
      live("/stores/:store/transactions", StoreTransactionsLive, :show)

      live("/stores/:store/settings", StoreSettingsLive, :redirect)
      live("/stores/:store/settings/general", StoreSettingsLive, :general)
      live("/stores/:store/settings/crypto/:crypto", StoreSettingsLive, :crypto)
      live("/stores/:store/settings/exchange_rates", StoreSettingsLive, :exchange_rates)
      live("/stores/:store/settings/invoices", StoreSettingsLive, :invoices)
      live("/stores/:store/settings/access_tokens", StoreSettingsLive, :access_tokens)

      live("/backends/:crypto", BackendLive, :show)
    end
  end

  live_session :admin_portal, on_mount: UserLiveAuth do
    scope "/", BitPalWeb do
      pipe_through([:authenticated_portal])

      # live("/server/backends", ServerBackendsLive, :index)
      # live("/server/backends/:backend", ServerBackendLive, :show)

      live("/server/settings", ServerSettingsLive, :redirect)
      live("/server/settings/backends", ServerSettingsLive, :backends)
      live("/server/settings/users", ServerSettingsLive, :users)
    end

    scope "/", BitPalWeb do
      pipe_through([:setup_wizard, :redirect_unless_server_setup, :require_authenticated_user])

      live("/server/setup/wizard", ServerSetupLive, :wizard)
    end
  end

  scope "/", BitPalWeb do
    pipe_through([:setup_wizard, :redirect_if_server_admin_created])

    get("/server/setup/server_admin", ServerSetupAdminController, :show)
    post("/server/setup/server_admin", ServerSetupAdminController, :create)
  end

  scope "/", BitPalWeb do
    pipe_through([:authenticated_portal])

    live_dashboard("/server/dashboard", metrics: BitPalWeb.Telemetry)
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
