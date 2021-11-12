defmodule BitPalFactory do
  use Supervisor

  @moduledoc """
  Factory creation functions

  Some conventions:
  - `create_` creates and inserts a resource into the db.
  - `with_` creates another resource and associates it with the current resource (and returns the current).
  - `assoc_` associates two created resources.
  - `get_or_create_` gets a resource from params or creates it.

  Note that create_invoice will *not* track it, for that we need to ...
  """

  defmacro __using__(_opts) do
    quote do
      import BitPalFactory.AccountFactory
      import BitPalFactory.AddressFactory
      import BitPalFactory.AuthFactory
      import BitPalFactory.CurrencyFactory
      import BitPalFactory.InvoiceFactory
      import BitPalFactory.SettingsFactory
      import BitPalFactory.StoreFactory
      import BitPalFactory.TransactionFactory
      import BitPalFactory.UtilFactory
    end
  end

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      BitPalFactory.Sequencer,
      BitPalFactory.CurrencyCounter
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
