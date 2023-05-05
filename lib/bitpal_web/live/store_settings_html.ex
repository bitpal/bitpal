defmodule BitPalWeb.StoreSettingsHTML do
  use BitPalWeb, :html

  import BitPalWeb.StoreHTML,
    only: [format_created_at: 1, format_last_accessed: 1, format_valid_until: 2]

  embed_templates "store_settings/*"
end
