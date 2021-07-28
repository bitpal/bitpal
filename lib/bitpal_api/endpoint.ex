defmodule BitPalApi.Endpoint do
  use Phoenix.Endpoint, otp_app: :bitpal

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_bitpal_api_key",
    signing_salt: "Naw2rZvg"
  ]

  socket("/socket", BitPalApi.StoreSocket,
    websocket: [connect_info: [:x_headers]],
    longpoll: false
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    # socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    # plug Phoenix.LiveReloader
    plug(Phoenix.CodeReloader)
    plug(Phoenix.Ecto.CheckRepoStatus, otp_app: :bitpal)
  end

  plug(Plug.RequestId)
  plug(Plug.Logger)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(BitPalApi.Router)
end
