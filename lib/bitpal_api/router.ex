defmodule BitPalApi.Router do
  use BitPalApi, :router
  alias BitPalApi.Authentication.BasicAuth

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :secure_api do
    plug(:api)
    plug(BasicAuth)
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
