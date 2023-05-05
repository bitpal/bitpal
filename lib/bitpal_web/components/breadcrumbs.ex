defmodule BitPalWeb.Breadcrumbs do
  use BitPalWeb, :verified_routes
  import Phoenix.LiveView.Helpers

  # The breadcrumbs are so short that the performance hit is negligible
  # and appending is more readable.
  # credo:disable-for-this-file Credo.Check.Refactor.AppendSingleItem

  def store(socket) do
    [
      live_redirect(
        "dashboard",
        to: ~p"/"
      ),
      live_redirect(
        socket.assigns.store.label,
        to: ~p"/stores/#{socket.assigns.store}/invoices"
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
          to: ~p"/stores/#{socket.assigns.store}/settings/general"
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
          to: ~p"/stores/#{socket.assigns.store}/invoices"
        ),
        live_redirect(invoice_id, to: uri)
      ]
  end

  def server_settings(socket, uri) do
    label =
      socket.assigns.live_action
      |> Atom.to_string()
      |> String.downcase()
      |> String.replace("_", " ")

    [
      live_redirect(
        "dashboard",
        to: ~p"/"
      ),
      live_redirect(
        "server settings",
        to: ~p"/server/settings/backends"
      ),
      live_redirect(label, to: uri)
    ]
  end

  def backend(_socket, uri, currency_id) do
    [
      live_redirect(
        "dashboard",
        to: ~p"/"
      ),
      live_redirect(
        currency_id,
        to: uri
      )
    ]
  end

  def exchange_rates(_socket) do
    [
      live_redirect(
        "dashboard",
        to: ~p"/"
      ),
      live_redirect(
        "exchange rates",
        to: ~p"/rates"
      )
    ]
  end
end
