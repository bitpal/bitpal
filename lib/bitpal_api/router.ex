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
    with {token, _} <- Plug.BasicAuth.parse_basic_auth(conn),
         {:ok, store_id} <- Authentication.authenticate_token(token) do
      assign(conn, :current_store, store_id)
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
    post("/invoices/:id/void", InvoiceController, :void)
    get("/invoices", InvoiceController, :index)

    get("/transactions/:txid", TransactionController, :show)
    get("/transactions", TransactionController, :index)

    get("/rates/:basecurrency", ExchangeRateController, :index)
    get("/rates/:basecurrency/:currency", ExchangeRateController, :show)

    get("/currencies", CurrencyController, :index)
    get("/currencies/:id", CurrencyController, :show)
  end
end
