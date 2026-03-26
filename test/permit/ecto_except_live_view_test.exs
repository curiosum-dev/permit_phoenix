defmodule Permit.EctoExceptLiveViewTest do
  @moduledoc """
  Tests for the except/0 callback in the LiveView authorization hook.
  """
  use Permit.RepoCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Permit.EctoLiveViewTest.{Endpoint, ExceptLive}
  alias Permit.EctoFakeApp.{Item, Repo}

  @endpoint Endpoint

  setup do
    %{users: users, items: items} = Repo.seed_data!()

    {:ok, %{users: users, items: items}}
  end

  describe "creator (no read permission) with except: [:index]" do
    setup [:creator_role, :init_session]

    test "can access excepted :index action without authorization", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/except_items")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert assigns[:mounted] == true
    end

    test "excepted action does not assign loaded_resources", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/except_items")

      assigns = get_assigns(lv)

      refute Map.has_key?(assigns, :loaded_resources)
      refute Map.has_key?(assigns, :loaded_resource)
    end

    test "non-excepted :show action still requires authorization", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/except_items")

      assigns = get_assigns(lv)
      assert :unauthorized not in Map.keys(assigns)

      # Navigate to a non-excepted action
      {:ok, lv, _html} = live(conn, "/live/except_items/1")

      assigns = get_assigns(lv)
      assert assigns[:unauthorized] == true
    end

    test "non-excepted :edit action still requires authorization", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/except_items/1/edit")

      assigns = get_assigns(lv)
      assert assigns[:unauthorized] == true
    end
  end

  describe "admin with except: [:index]" do
    setup [:admin_role, :init_session]

    test "admin can access excepted :index action", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/except_items")

      assigns = get_assigns(lv)
      assert :unauthorized not in Map.keys(assigns)
    end

    test "admin can also access non-excepted actions", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/except_items/1")

      assigns = get_assigns(lv)
      assert :unauthorized not in Map.keys(assigns)
      assert %{loaded_resource: %Item{id: 1}} = assigns
    end
  end

  # Helper functions

  defp admin_role(context) do
    {:ok, Map.put(context, :roles, [:admin])}
  end

  defp creator_role(context) do
    {:ok, Map.put(context, :roles, [:creator])}
  end

  defp init_session(%{roles: roles}) do
    {:ok,
     conn:
       Plug.Test.init_test_session(
         build_conn(),
         %{"token" => "valid_token", roles: roles}
       )}
  end

  defp get_assigns(lv) do
    ExceptLive.run(lv, fn socket -> {:reply, socket.assigns, socket} end)
  end
end
