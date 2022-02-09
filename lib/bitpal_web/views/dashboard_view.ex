defmodule BitPalWeb.DashboardView do
  use BitPalWeb, :view

  def format_status(assigns) do
    ~H"""
      <span class="status">
        <%= case @status do %>
          <% :initializing -> %>
            <span class="initializing">
              Initializing
            </span>
          <% {:recovering, current, target} -> %>
            <span class="recovering">
              Recovering <%= current %> / <%= target %>
            </span>
          <% {:syncing, progress} -> %>
            <span class="syncing">
              Syncing <%= Float.round(progress * 100, 1) %>%
            </span>
          <% :ready -> %>
            <span class="ready">
              Ready
            </span>
          <% :stopped -> %>
            <span class="stopped">
              Stopped
            </span>
          <% {:error, :econnrefused} -> %>
            <span class="error">
              Connection refused
            </span>
          <% {:error, error} -> %>
            <span class="error">
              Unknown error <%= inspect(error) %>
            </span>
          <% :not_found -> %>
            <span class="not-found">
              Not found
            </span>
        <% end %>
      </span>
    """
  end
end
