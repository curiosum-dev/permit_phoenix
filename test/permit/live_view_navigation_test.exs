defmodule Permit.LiveViewNavigationTest do
  @moduledoc """
  Tests for LiveView navigation behavior introduced in commit b34e665.

  This test suite covers:
  1. navigate_if_mounting/2 behavior - only navigates during mount, not handle_params
  2. handle_unauthorized/2 respects the mounting phase
  3. fallback_path/3 behavior with custom options

  Note: Testing _live_referer directly is challenging because it's set automatically by
  Phoenix LiveView during live navigation. These tests focus on the navigate_if_mounting
  behavior which is the key change in the commit.
  """
  use Permit.RepoCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Permit.EctoLiveViewTest.{Endpoint, HooksLive, DefaultBehaviorLive}
  alias Permit.EctoFakeApp.Repo

  @endpoint Endpoint

  setup do
    %{users: users, items: items} = Repo.seed_data!()
    {:ok, %{users: users, items: items}}
  end

  describe "navigate_if_mounting behavior - unauthorized during mount" do
    setup [:inspector_role, :init_session]

    test "redirects when unauthorized during mount phase", %{conn: conn} do
      # Inspector cannot create items, so mounting /default_items/new should redirect
      # This tests that navigate_if_mounting calls navigate during mount
      assert {:error, {:live_redirect, redirect_info}} =
               conn
               |> fetch_flash()
               |> live("/live/default_items/new")

      assert %{to: _path, flash: %{"error" => error}} = redirect_info
      assert error =~ "permission"
    end

    test "redirects with flash message during mount", %{conn: conn} do
      # Verify the error message is set correctly
      assert {:error, {:live_redirect, %{flash: %{"error" => error}}}} =
               conn
               |> fetch_flash()
               |> live("/live/default_items/new")

      assert error == "You do not have permission to perform this action."
    end

    test "fallback_path returns '/' by default when no _live_referer", %{conn: conn} do
      # When there's no _live_referer (normal HTTP request), should fall back to "/live/"
      assert {:error, {:live_redirect, %{to: "/"}}} =
               conn
               |> fetch_flash()
               |> live("/live/default_items/new")
    end
  end

  describe "navigate_if_mounting behavior - unauthorized during handle_params" do
    setup [:inspector_role, :init_session]

    test "does NOT redirect when unauthorized during handle_params", %{conn: conn} do
      # This is the key test for the navigate_if_mounting change
      # Mount at authorized page (/default_items - inspector can view)
      {:ok, lv, _html} = live(conn, "/live/default_items")

      # Navigate to unauthorized page (/default_items/1/edit - inspector cannot edit) via handle_params
      # With the new navigate_if_mounting, this should NOT redirect
      lv |> element("#navigate_edit") |> render_click()

      # LiveView should still be connected and not redirected
      # This is the key difference from the old behavior
      assert Process.alive?(lv.pid)
    end

    test "LiveView remains alive after unauthorized handle_params navigation", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/default_items")

      # Try to navigate to edit page (unauthorized for inspector)
      lv |> element("#navigate_edit") |> render_click()

      # Verify the LiveView is still running and hasn't been terminated by a redirect
      assert Process.alive?(lv.pid)

      # The socket should still be valid and responsive
      assert render(lv) =~ "navigate_edit"
    end

    test "handles multiple unauthorized navigations without redirecting", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/default_items")

      # Multiple unauthorized navigations via handle_params should all work without redirect
      lv |> element("#navigate_edit") |> render_click()
      assert Process.alive?(lv.pid)

      lv |> element("#navigate_show") |> render_click()
      assert Process.alive?(lv.pid)

      # LiveView should still be responsive
      assert render(lv) =~ "navigate"
    end
  end

  describe "navigate_if_mounting with authorized actions" do
    setup [:admin_role, :init_session]

    test "does not interfere with authorized mount", %{conn: conn} do
      # Admin can create items, verify navigate_if_mounting doesn't break authorized flows
      {:ok, lv, _html} = live(conn, "/live/default_items/new")

      assigns = get_assigns(lv, DefaultBehaviorLive)

      # Should mount successfully
      assert assigns.mounted == true
      refute assigns[:unauthorized]
    end

    test "does not interfere with authorized handle_params navigation", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/default_items")

      # Navigate to edit (authorized for admin)
      lv |> element("#navigate_edit") |> render_click()

      assigns = get_assigns(lv, DefaultBehaviorLive)

      # Should have loaded resource
      assert assigns.loaded_resource
      refute assigns[:unauthorized]
    end

    test "authorized mount does not trigger navigation", %{conn: conn} do
      # Verify no unexpected redirects for authorized users
      result = conn |> fetch_flash() |> live("/live/default_items/new")

      assert {:ok, _lv, _html} = result
      refute match?({:error, {:live_redirect, _}}, result)
    end
  end

  describe "custom fallback_path option" do
    setup [:inspector_role, :init_session]

    test "custom fallback_path function takes precedence over default behavior", %{conn: conn} do
      # HooksWithCustomOptsLive has custom fallback_path that returns "/live/?foo"
      # This should override the default _live_referer logic
      assert {:error, {:live_redirect, %{to: to, flash: %{"error" => error}}}} =
               conn
               |> fetch_flash()
               |> live("/live/items_custom/2/edit")

      # Should use custom path
      assert to == "/live/?foo"

      # Should use custom unauthorized message
      assert error == "Lorem ipsum."
    end
  end

  describe "mounting? function behavior" do
    setup [:inspector_role, :init_session]

    test "mounting? returns true during mount - causes redirect when unauthorized", %{conn: conn} do
      # This implicitly tests that mounting? returns true during mount
      # Because navigate_if_mounting calls navigate, which triggers redirect
      assert {:error, {:live_redirect, _}} =
               conn
               |> fetch_flash()
               |> live("/live/default_items/new")
    end

    test "mounting? returns false during handle_params - no redirect when unauthorized", %{
      conn: conn
    } do
      # This implicitly tests that mounting? returns false during handle_params
      # Because navigate_if_mounting returns socket unchanged, so no redirect
      {:ok, lv, _html} = live(conn, "/live/default_items")

      # Navigate via handle_params - should not redirect
      lv |> element("#navigate_edit") |> render_click()

      # Should still be alive (not redirected)
      assert Process.alive?(lv.pid)
    end
  end

  describe "fallback_path implementation details" do
    setup [:inspector_role, :init_session]

    test "falls back to '/' when _live_referer is not available", %{conn: conn} do
      # During a normal HTTP mount (not from live navigation), there's no _live_referer
      # So it should fall back to "/"
      assert {:error, {:live_redirect, %{to: "/"}}} =
               conn
               |> fetch_flash()
               |> live("/live/default_items/new")
    end

    test "fallback_path handles RuntimeError gracefully", %{conn: conn} do
      # During handle_params (not mounting), get_connect_params raises RuntimeError
      # The fallback_path function rescues this and falls back to "/live/"
      {:ok, lv, _html} = live(conn, "/live/default_items")

      # Navigate to trigger unauthorized during handle_params
      # The fallback_path will be called but get_connect_params will raise RuntimeError
      lv |> element("#navigate_edit") |> render_click()

      # LiveView should still be alive and not crash
      assert Process.alive?(lv.pid)
    end
  end

  describe "navigate_if_mounting behavior - unauthorized handle_event" do
    setup [:inspector_role, :init_session]

    test "does NOT redirect when unauthorized during handle_event", %{conn: conn} do
      # This is a critical test for the navigate_if_mounting change
      # Mount at authorized page (/default_items - inspector can view)
      {:ok, lv, _html} = live(conn, "/live/default_items")

      # Trigger an unauthorized event (delete - inspector cannot delete)
      # With navigate_if_mounting, this should NOT redirect
      lv |> element("#delete") |> render_click()

      # LiveView should still be connected and not redirected
      assert Process.alive?(lv.pid)

      # Verify the LiveView is still responsive
      assert render(lv) =~ "delete"
    end

    test "LiveView remains responsive after multiple unauthorized events", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/default_items")

      # Try multiple unauthorized events
      lv |> element("#delete") |> render_click()
      assert Process.alive?(lv.pid)

      lv |> element("#update") |> render_click()
      assert Process.alive?(lv.pid)

      # Should still render the page
      html = render(lv)
      assert html =~ "delete"
      assert html =~ "update"
    end

    test "handle_event authorization with default handle_unauthorized", %{conn: conn} do
      # Inspector can view items but cannot delete
      {:ok, lv, _html} = live(conn, "/live/default_items")

      # Before triggering unauthorized event
      assert Process.alive?(lv.pid)

      # Trigger delete (unauthorized for inspector)
      lv |> element("#delete") |> render_click()

      # With navigate_if_mounting, the socket should remain alive (no redirect)
      # This is different from mount phase where it would redirect
      assert Process.alive?(lv.pid)
    end
  end

  describe "handle_event with authorized actions" do
    setup [:admin_role, :init_session]

    test "authorized handle_event works normally", %{conn: conn} do
      # Admin can delete items
      {:ok, lv, _html} = live(conn, "/live/default_items")

      # Trigger delete (authorized for admin)
      lv |> element("#delete") |> render_click()

      # Should work fine without any authorization issues
      assert Process.alive?(lv.pid)
    end

    test "multiple authorized events work correctly", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/default_items")

      # Multiple authorized events should all work
      lv |> element("#delete") |> render_click()
      lv |> element("#update") |> render_click()

      assert Process.alive?(lv.pid)
      assert render(lv) =~ "delete"
    end
  end

  describe "HooksLive with custom handle_unauthorized" do
    setup [:inspector_role, :init_session]

    test "custom handle_unauthorized is not affected by navigate_if_mounting", %{conn: conn} do
      # HooksLive overrides handle_unauthorized to just set an assign
      # Verify that navigate_if_mounting doesn't break custom implementations
      {:ok, lv, _html} = live(conn, "/live/items/new")

      assigns = get_assigns(lv, HooksLive)

      # Custom implementation sets unauthorized assign without redirecting
      assert assigns.unauthorized == true
      assert assigns.mounted == true
    end

    test "custom handle_unauthorized works during handle_params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/items")

      lv |> element("#navigate_edit") |> render_click()

      assigns = get_assigns(lv, HooksLive)

      # Should set unauthorized flag
      assert assigns.unauthorized == true

      # LiveView should still be connected
      assert Process.alive?(lv.pid)
    end

    test "custom handle_unauthorized works during handle_event", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/live/items")

      # Trigger unauthorized delete event
      lv |> element("#delete") |> render_click()

      assigns = get_assigns(lv, HooksLive)

      # Custom implementation sets unauthorized flag
      assert assigns.unauthorized == true

      # LiveView should still be connected (not redirected)
      assert Process.alive?(lv.pid)
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

  defp get_assigns(lv, live_module) do
    live_module.run(lv, fn socket -> {:reply, socket.assigns, socket} end)
  end
end
