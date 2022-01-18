defmodule BitPalWeb.HomeView do
  use BitPalWeb, :view

  def format_status({currency_id, status}) do
    view_status(%{currency_id: currency_id, status: status})
  end

  def view_status(assigns) do
    ~H"""
    <div class="backend-row">
      <span class="currency">
        <%= @currency_id %>
      </span>
      <span class="status">
        <%= case @status do %>
          <% {:started, :ready} -> %>
            <span class="started">
              Started
            </span>
          <% {:started, {:syncing, state}} -> %>
            <span class="syncing">
              Syncing <%= state %>
            </span>
          <% :stopped -> %>
            <span class="stopped">
              Stopped
            </span>
          <% :not_found -> %>
            <span class="not-found">
              Not found
            </span>
        <% end %>
      </span>
    </div>
    """
  end
end
