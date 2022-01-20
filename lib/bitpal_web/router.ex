defmodule BitPalWeb.Router do
  use BitPalWeb, :router

  import BitPalWeb.UserAuth
  import BitPalWeb.ServerSetup
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {BitPalWeb.LayoutView, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_user)
  end

  pipeline :portal_layout do
    plug(:put_root_layout, {BitPalWeb.LayoutView, :portal})
  end

  pipeline :doc_layout do
    plug(:put_root_layout, {BitPalWeb.LayoutView, :doc})
  end

  pipeline :portal do
    plug(:browser)
    plug(:server_setup_redirect)
    plug(:portal_layout)
  end

  pipeline :authenticated_portal do
    plug(:portal)
    plug(:require_authenticated_user)
  end

  # Store management

  scope "/", BitPalWeb do
    pipe_through([:authenticated_portal])

    live("/", HomeLive, :dashboard)
    live("/stores/:slug", StoreLive, :show)
    live("/stores/:slug/addresses", StoreAddressesLive, :show)
    live("/stores/:slug/transactions", StoreTransactionsLive, :show)
    live("/stores/:slug/settings", StoreSettingsLive, :show)

    live("/invoices/:id", InvoiceLive, :show)
  end

  # Admin and server management

  scope "/", BitPalWeb do
    pipe_through([:authenticated_portal])

    live("/server/settings", ServerSettingsLive, :show)
    live_dashboard("/dashboard", metrics: BitPalWeb.Telemetry)
  end

  # Setup routes

  scope "/", BitPalWeb do
    pipe_through([:portal, :redirect_if_setup_completed])

    get("/server/setup/register_admin", ServerSetupController, :register_admin)
    post("/server/setup/register_admin", ServerSetupController, :create_admin)
    get("/server/setup/info", ServerSetupController, :info)
  end

  # Authentication routes

  scope "/", BitPalWeb do
    pipe_through([:portal, :redirect_if_user_is_authenticated])

    # Add these back later when we can invite people
    get("/users/register", UserRegistrationController, :new)
    post("/users/register", UserRegistrationController, :create)
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
