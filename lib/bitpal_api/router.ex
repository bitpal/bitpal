defmodule BitPalApi.Router do
  use BitPalApi, :router
  alias BitPal.Authentication
  alias BitPalApi.UnauthorizedError

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :secure_api do
    plug(:api)
    plug(:basic_auth)
  end

  defp basic_auth(conn, _opts) do
    with {user, pass} <- Plug.BasicAuth.parse_basic_auth(conn),
         true <- Authentication.authenticate(user, pass) do
      assign(conn, :current_user, user)
    else
      _ -> raise UnauthorizedError
    end
  end

  scope "/v1", BitPalApi do
    pipe_through(:secure_api)

    post("/invoices", InvoiceController, :create)
    get("/invoices/:id", InvoiceController, :show)
    post("/invoices/:id", InvoiceController, :update)
    delete("/invoices/:id", InvoiceController, :delete)
    post("/invoices/:id/finalize", InvoiceController, :finalize)
    post("/invoices/:id/pay", InvoiceController, :pay)
    post("/invoices/:id/send", InvoiceController, :send)
    post("/invoices/:id/void", InvoiceController, :void)
    post("/invoices/:id/mark_uncollectible", InvoiceController, :mark_uncollectible)
    get("/invoices", InvoiceController, :index)

    get("/transactions/:id", TransactionController, :show)
    get("/transactions", TransactionController, :index)

    # Also need to list available rates
    # get "/rates/:pair", ExchangeRateController, :show
    #
    # get "/events", EventsController, :index
    # get "/events/:id", EventsController, :show

    # post "/webhook_endpoints", WebhookController, :create

    # Stripe
    # POST /v1/invoices
    # GET /v1/invoices/:id
    # POST /v1/invoices/:id
    # DELETE /v1/invoices/:id
    # POST /v1/invoices/:id/finalize
    # POST /v1/invoices/:id/pay
    # POST /v1/invoices/:id/send
    # POST /v1/invoices/:id/void
    # POST /v1/invoices/:id/mark_uncollectible
    # GET /v1/invoices/:id/lines
    # GET /v1/invoices/upcoming
    # GET /v1/invoices/upcoming/lines
    # GET /v1/invoices

    # GET /v1/issuing/transactions/:id
    # POST /v1/issuing/transactions/:id
    # GET /v1/issuing/transactions

    # POST /v1/webhook_endpoints
    # GET /v1/webhook_endpoints/:id
    # POST /v1/webhook_endpoints/:id
    # GET /v1/webhook_endpoints
    # DELETE /v1/webhook_endpoints/:id
    #
    #
    # When interesting stuff happens
    # GET /v1/events/:id
    # GET /v1/events
  end

  # Server based payment UI

  # Admin portal

  # REST API
end
