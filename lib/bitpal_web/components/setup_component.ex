defmodule BitPal.SetupComponent do
  use BitPalWeb, :component

  def layout(assigns) do
    ~H"""
    <header>
      <div class="title">
        <h1>BitPal server setup</h1>
      </div>
    </header>

    <section class="setup create_store">
      <div class="description">
        <h2><%= render_slot(@header) %></h2>
      </div>

      <%= render_slot(@inner_block) %>
    </section>

    <div class="floating-footer">
      <%= link("Read the documentation", to: "/doc") %>
    </div>
    """
  end
end
