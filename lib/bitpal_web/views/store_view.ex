defmodule BitPalWeb.StoreView do
  use BitPalWeb, :view
  alias BitPalSchemas.Invoice
  alias BitPal.Invoices
  alias BitPal.Currencies

  def format_status(invoice = %Invoice{}) do
    # FIXME Also need to detect underpaid and overpaid!
    assigns = %{
      status: readable_status(invoice.status),
      reason: readable_status_reason(invoice),
      date: ""
      # date: NaiveDateTime.to_date(invoice.updated_at)
    }

    ~H"""
    <span class="main-status">
      <%= @status %>
      <span class="date"><%= @date %></span>
    </span>
    <%= @reason %>
    """
  end

  # FIXME wrap in status class
  defp readable_status(status) do
    tag = Atom.to_string(status)
    readable = tag |> String.capitalize()

    assigns = %{
      tag: tag,
      readable: readable
    }

    ~H"""
    <span class={"invoice-status #{@tag}"}><%= @readable %></span>
    """
  end

  defp readable_status_reason(invoice) do
    msg = readable_status_reason_msg(invoice)

    if msg != "" do
      assigns = %{msg: msg}

      ~H"""
      <span class="status-reason"><%= @msg %></span>
      """
    else
      ""
    end
  end

  # Ignore status reason when in void status, to not overwhelm with info
  defp readable_status_reason_msg(%Invoice{status: :void}) do
    ""
  end

  defp readable_status_reason_msg(%Invoice{status_reason: :verifying}) do
    "Verifying 0-conf"
  end

  defp readable_status_reason_msg(invoice = %Invoice{status_reason: :confirming}) do
    # FIXME this is slow, as it forces txs to be reloaded
    # Maybe we could have the invoices be loaded with txs directly?
    invoice = Invoices.update_info_from_txs(invoice)

    have = invoice.required_confirmations - invoice.confirmations_due
    "Confirming #{have}/#{invoice.required_confirmations}"
  end

  defp readable_status_reason_msg(%Invoice{status_reason: :expired}) do
    "Expired"
  end

  defp readable_status_reason_msg(%Invoice{status_reason: :canceled}) do
    "Canceled by user"
  end

  defp readable_status_reason_msg(%Invoice{status_reason: :double_spent}) do
    "Double spend detected"
  end

  defp readable_status_reason_msg(%Invoice{status_reason: :timed_out}) do
    "Payment timed out"
  end

  defp readable_status_reason_msg(%Invoice{status_reason: nil}) do
    ""
  end

  # def format_date(invoice) do
  #   DateTime.to_date(invoice.inserted_at)
  # end

  def format_amount(invoice) do
    invoice.amount |> money_to_string()
  end

  def format_fiat_amount(invoice) do
    invoice.fiat_amount |> money_to_string()
  end

  def money_to_string(money) do
    Money.to_string(money, money_format_args(money.currency))
  end

  def money_format_args(:SEK) do
    [separator: "", delimiter: ".", symbol_space: true, symbol_on_right: true]
  end

  def money_format_args(id) do
    if Currencies.is_crypto(id) do
      [symbol_space: true, symbol_on_right: true]
    else
      []
    end
  end

  def live_store_link(opts) do
    to = Keyword.fetch!(opts, :to)
    from = Keyword.fetch!(opts, :from)
    label = Keyword.fetch!(opts, :label)

    to_path = URI.parse(to).path
    from_path = URI.parse(from).path

    if to_path == from_path do
      live_redirect(label, to: to, class: "active")
    else
      live_redirect(label, to: to)
    end
  end
end
