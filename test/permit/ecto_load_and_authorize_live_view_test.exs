defmodule Permit.EctoLoadAndAuthorizeLiveViewTest do
  @moduledoc """
  Tests for the load_and_authorize/5 public function in LiveView.
  """
  use Permit.RepoCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Permit.EctoLiveViewTest.{Endpoint, LoadAndAuthorizeLive}
  alias Permit.EctoFakeApp.{Item, Repo}

  @endpoint Endpoint

  setup do
    %{users: users, items: items} = Repo.seed_data!()

    {:ok, %{users: users, items: items}}
  end

  describe "admin loads resources via load_and_authorize" do
    setup [:admin_role, :init_session]

    test "can load a singular resource", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/load_authorize_items")

      lv |> element("#load_one") |> render_click()

      assigns = get_assigns(lv)
      assert %Item{id: 1} = assigns[:manual_resource]
    end

    test "can load a plural resource", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/load_authorize_items")

      lv |> element("#load_all") |> render_click()

      assigns = get_assigns(lv)
      assert is_list(assigns[:manual_resources])
      assert length(assigns[:manual_resources]) == 3
    end

    test "returns :not_found for nonexistent record", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/load_authorize_items")

      lv |> element("#load_nonexistent") |> render_click()

      assigns = get_assigns(lv)
      assert assigns[:manual_not_found] == true
    end

    test "does not modify hook-assigned loaded_resources", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/load_authorize_items")

      # The hook assigns loaded_resources for :index
      assigns_before = get_assigns(lv)
      loaded_before = assigns_before[:loaded_resources]

      lv |> element("#load_one") |> render_click()

      assigns_after = get_assigns(lv)
      # Hook's loaded_resources should be unchanged
      assert assigns_after[:loaded_resources] == loaded_before
    end
  end

  describe "inspector (read-only) loads resources via load_and_authorize" do
    setup [:inspector_role, :init_session]

    test "can load a singular resource with :show action", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/load_authorize_items")

      lv |> element("#load_one") |> render_click()

      assigns = get_assigns(lv)
      assert %Item{id: 1} = assigns[:manual_resource]
    end

    test "gets :unauthorized for :edit action", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/load_authorize_items")

      lv |> element("#edit_one") |> render_click()

      assigns = get_assigns(lv)
      assert assigns[:manual_edit_unauthorized] == true
    end
  end

  # Helper functions

  defp admin_role(context) do
    {:ok, Map.put(context, :roles, [:admin])}
  end

  defp inspector_role(context) do
    {:ok, Map.put(context, :roles, [:inspector])}
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
    LoadAndAuthorizeLive.run(lv, fn socket -> {:reply, socket.assigns, socket} end)
  end
end
