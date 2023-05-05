defmodule BitPalWeb.ServerSetupHTML do
  use BitPalWeb, :html
  import BitPal.SetupComponent

  embed_templates "server_setup/*"
end
