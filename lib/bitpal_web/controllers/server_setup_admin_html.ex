defmodule BitPalWeb.ServerSetupAdminHTML do
  use BitPalWeb, :html
  import BitPal.SetupComponent

  embed_templates "server_setup_admin/*"
end
