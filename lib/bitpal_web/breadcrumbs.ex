defmodule BitPalWeb.Breadcrumbs do
  import Phoenix.LiveView.Helpers
  alias BitPalWeb.Router.Helpers, as: Routes

  # The breadcrumbs are so short that the performance hit is negligible
  # and appending is more readable.
  # credo:disable-for-this-file Credo.Check.Refactor.AppendSingleItem

  def store(socket) do
    [
      live_redirect(
        "stores",
        to: Routes.dashboard_path(socket, :show)
      ),
      live_redirect(
        socket.assigns.store.label,
        to: Routes.store_invoices_path(socket, :show, socket.assigns.store)
      )
    ]
  end

  def store(socket, uri, label) do
    store(socket) ++
      [
        live_redirect(label, to: uri)
      ]
  end

  def store_settings(socket) do
    store(socket) ++
      [
        live_redirect(
          "settings",
          to: Routes.store_settings_path(socket, :general, socket.assigns.store)
        )
      ]
  end

  def store_settings(socket, uri) do
    label =
      socket.assigns.live_action
      |> Atom.to_string()
      |> String.downcase()
      |> String.replace("_", " ")

    store_settings(socket) ++
      [
        live_redirect(label, to: uri)
      ]
  end

  def store_backend_settings(socket, uri, currency_id) do
    store_settings(socket) ++
      [
        live_redirect(currency_id, to: uri)
      ]
  end

  def invoice(socket, uri, invoice_id) do
    store(socket) ++
      [
        live_redirect(
          "invoices",
          to: Routes.store_invoices_path(socket, :show, socket.assigns.store)
        ),
        live_redirect(invoice_id, to: uri)
      ]
  end
end
