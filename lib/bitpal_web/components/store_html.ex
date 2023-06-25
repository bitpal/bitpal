defmodule BitPalWeb.StoreHTML do
  use BitPalWeb, :html
  alias BitPal.Invoices
  alias BitPalSchemas.AccessToken
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.InvoiceStatus

  @dialyzer {:nowarn_function, format_pos_data: 1}

  embed_templates "store/*"

  def format_status(invoice = %Invoice{}) do
    assigns = %{
      status: readable_status(invoice.status),
      reason: readable_status_reason(invoice),
      date: ""
      # date: DateTime.to_date(invoice.updated_at)
    }

    ~H"""
    <span class="main-status">
      <%= @status %>
      <span class="date"><%= @date %></span>
    </span>
    <%= @reason %>
    """
  end

  defp readable_status(status) do
    tag = Atom.to_string(InvoiceStatus.state(status))
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

  defp readable_status_reason_msg(%Invoice{status: {_, :verifying}}) do
    "Verifying 0-conf"
  end

  defp readable_status_reason_msg(invoice = %Invoice{status: {_, :confirming}}) do
    # This is slow, as it forces txs to be reloaded
    # Maybe we could have the invoices be loaded with txs directly?
    invoice = Invoices.update_info_from_txs(invoice)

    have = invoice.required_confirmations - invoice.confirmations_due
    "Confirming #{have}/#{invoice.required_confirmations}"
  end

  defp readable_status_reason_msg(%Invoice{status: {_, :expired}}) do
    "Expired"
  end

  defp readable_status_reason_msg(%Invoice{status: {_, :canceled}}) do
    "Canceled by user"
  end

  defp readable_status_reason_msg(%Invoice{status: {_, :double_spent}}) do
    "Double spend detected"
  end

  defp readable_status_reason_msg(%Invoice{status: {_, :timed_out}}) do
    "Payment timed out"
  end

  defp readable_status_reason_msg(%Invoice{status: _}) do
    ""
  end

  # def format_date(invoice) do
  #   DateTime.to_date(invoice.inserted_at)
  # end

  def live_invoice_link(opts) do
    id = Keyword.fetch!(opts, :id)
    label = Keyword.fetch!(opts, :label)

    live_redirect(label, to: ~p"/invoices/#{id}")
  end

  def tx_status(assigns) do
    ~H"""
    <span class="tx-status">
      <%= cond do %>
        <% @tx.height != 0 -> %>
          <span class="confirmed">Confirmed</span>
        <% @tx.failed -> %>
          <span class="failed">Failed</span>
        <% @tx.double_spent -> %>
          <span class="double-spent">Double spent</span>
        <% true -> %>
          <span class="unconfirmed">Unconfirmed</span>
      <% end %>
      <%= if @tx.height != 0 do %>
        <span class="block-height">
          <%= "Block #{@tx.height}" %>
        </span>
      <% end %>
    </span>
    """
  end

  def format_created_at(token = %AccessToken{}) do
    Timex.format!(token.created_at, "{ISOdate}")
  end

  def format_last_accessed(token = %AccessToken{}) do
    if token.last_accessed do
      Timex.format!(token.last_accessed, "{relative}", :relative)
    else
      "Never"
    end
  end

  def format_valid_until(token = %AccessToken{}, now = %DateTime{}) do
    eod =
      now
      |> DateTime.to_date()
      |> DateTime.new!(Time.new!(23, 59, 59, 0))
      |> DateTime.truncate(:second)

    if token.valid_until do
      if DateTime.compare(token.valid_until, eod) == :lt do
        Timex.format!(token.valid_until, "{relative}", :relative)
      else
        Timex.format!(token.valid_until, "{ISOdate}")
      end
    else
      "Never"
    end
  end

  def format_pos_data(data) do
    case Jason.encode(data, pretty: true) do
      {:ok, encoded} -> encoded
      {:error, err} -> "Error displaying POS data: #{err}"
    end
  end
end
