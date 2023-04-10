defmodule BitPalApi.StoreChannelTest do
  use BitPalApi.ChannelCase, async: true, integration: true
  alias BitPal.Invoices

  setup _tags do
    store = create_store()

    {:ok, _, socket} =
      BitPalApi.StoreSocket
      |> socket(nil, %{store_id: store.id})
      |> subscribe_and_join(BitPalApi.StoreChannel, "store:#{store.id}")

    %{socket: socket, store_id: store.id}
  end

  describe "create_invoice" do
    test "standard fields", %{socket: socket} do
      ref =
        push(socket, "create_invoice", %{
          subPrice: 120,
          priceCurrency: "USD",
          description: "My awesome invoice",
          email: "test@bitpal.dev",
          orderId: "id:123",
          posData: %{
            "some" => "data",
            "other" => %{"even_more" => 0.1337}
          }
        })

      assert_reply(ref, :ok, %{
        id: id,
        subPrice: 120,
        priceCurrency: :USD,
        description: "My awesome invoice",
        email: "test@bitpal.dev",
        orderId: "id:123",
        posData: %{
          "some" => "data",
          "other" => %{"even_more" => 0.1337}
        }
      })

      assert Invoices.fetch!(id)
    end

    test "creation failed", %{socket: socket} do
      ref = push(socket, "create_invoice", %{})

      assert_reply(ref, :error, %{
        errors: %{
          price: "either `price` or `subPrice` must be provided",
          priceCurrency: "can't be blank",
          subPrice: "either `price` or `subPrice` must be provided"
        },
        message: "Request Failed",
        type: "invalid_request_error"
      })
    end
  end

  describe "get_invoice" do
    test "existing", %{socket: socket, store_id: store_id} do
      invoice = create_invoice(%{store_id: store_id})
      id = invoice.id
      sub_price = invoice.price.amount

      ref = push(socket, "get_invoice", %{id: id})
      assert_reply(ref, :ok, %{id: ^id, subPrice: ^sub_price})
    end

    test "not found", %{socket: socket} do
      ref = push(socket, "get_invoice", %{id: "xxx"})

      assert_reply(ref, :error, %{
        code: "resource_missing",
        message: "Not Found",
        type: "invalid_request_error"
      })
    end
  end

  describe "list_invoices" do
    test "list multiple", %{socket: socket, store_id: store_id} do
      i1 = create_invoice(%{store_id: store_id})
      i2 = create_invoice(%{store_id: store_id})

      id1 = i1.id
      id2 = i2.id

      ref = push(socket, "list_invoices", %{})
      assert_reply(ref, :ok, [%{id: ^id1}, %{id: ^id2}])
    end
  end

  describe "authorization" do
    test "unauthorized", %{store_id: store_id} do
      %{token: token} = create_auth()
      {:ok, socket} = connect(BitPalApi.StoreSocket, %{"token" => token}, %{})

      {:error, %{message: "Unauthorized", type: "api_connection_error"}} =
        subscribe_and_join(socket, "store:#{store_id}")
    end
  end
end
