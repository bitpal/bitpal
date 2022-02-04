defmodule BitPalWeb.CreateStoreLiveTest do
  use BitPalWeb.ConnCase, integration: true, async: true
  alias BitPal.Repo
  alias BitPalFactory.StoreFactory

  setup tags do
    tags
    |> register_and_log_in_user()
  end

  describe "create store" do
    test "creates a store and lists it", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, Routes.create_store_path(conn, :show))

      label = StoreFactory.unique_store_label()

      assert {:error, {:live_redirect, _}} =
               view
               |> element("form")
               |> render_submit(%{"store" => %{label: label}})

      user = user |> Repo.preload(:stores)
      assert length(user.stores) == 1
      assert hd(user.stores).label == label
    end

    test "renders errors if invalid", %{conn: conn, user: _user} do
      {:ok, view, _html} = live(conn, Routes.create_store_path(conn, :show))

      rendered =
        view
        |> element("form")
        |> render_submit(%{"store" => %{label: ""}})

      assert rendered =~ html_string("can't be blank")
    end
  end
end
