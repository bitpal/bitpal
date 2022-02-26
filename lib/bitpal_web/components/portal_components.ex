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
    assigns =
      assigns
      |> Map.put(:extra_class, Map.get(assigns, :class, ""))
      |> Map.put_new(:header, true)

    ~H"""
    <table class={"flex-table #{@extra_class}"}>
      <%= if @header do %>
        <thead>
          <tr>
            <%= for col <- @col do %>
              <th><%= col.label %></th>
            <% end %>
          </tr>
        </thead>
      <% end %>
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

  def side_nav(assigns) do
    ~H"""
    <div class="side-nav-wrapper">
      <nav class="side-nav">
        <%= for group <- @group do %>
          <div class="group">
            <%= if label = group[:label] do %>
              <div class="label">
                <%= label %>
              </div>
            <% end %>

            <ul>
              <%= for {label, to} <- group.links do %>
                <li>
                  <%= active_live_link(
                    to: to,
                    from: @uri,
                    label: label,
                    patch: true
                  ) %>
                </li>
              <% end %>
            </ul>
          </div>
        <% end %>
      </nav>

      <div class="side-content">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end
end
