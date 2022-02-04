defmodule BitPalWeb.PortalComponent do
  use BitPalWeb, :component

  def breadcrumbs(assigns) do
    ~H"""
    <nav class="breadcrumbs">
      <%= for {part, i} <- Enum.with_index(@breadcrumbs) do %>
        <%= if i > 0 do %>
          /
        <% end %>
        <span class="part"><%= part %></span>
      <% end %>
    </nav>
    """
  end

  def dashboard_breadcrumbs(assigns) do
    breadcrumbs(%{
      breadcrumbs: [live_redirect("dashboard", to: Routes.dashboard_path(assigns.socket, :show))]
    })
  end

  def flex_table(assigns) do
    assigns = Map.put(assigns, :extra_class, Map.get(assigns, :class, ""))

    ~H"""
      <table class={"flex-table #{@extra_class}"}>
        <thead>
          <tr>
            <%= for col <- @col do %>
              <th><%= col.label %></th>
            <% end %>
          </tr>
        </thead>
        <tbody>
          <%= for row <- @rows do %>
            <tr>
              <%= for col <- @col do %>
                <td><%= render_slot(col, row) %></td>
              <% end %>
            </tr>
          <% end %>
        </tbody>
      </table>
    """
  end
end
