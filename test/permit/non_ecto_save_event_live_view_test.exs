defmodule Permit.NonEctoSaveEventLiveViewTest do
  @moduledoc """
  Tests for LiveView handle_event authorization with "save" events that contain
  form payloads instead of IDs. Tests both reload_on_event? behaviors:
  - reload_on_event? = true (default): reloads the resource before authorization
  - reload_on_event? = false: uses the already loaded resource from assigns
  """
  use Permit.RepoCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Permit.NonEctoLiveViewTest.{Endpoint, SaveEventLoaderLive, SaveEventLoaderNoReloadLive}
  alias Permit.NonEctoFakeApp.Item

  @endpoint Endpoint

  setup do
    users = Permit.NonEctoFakeApp.SeedData.users()
    items = Permit.NonEctoFakeApp.SeedData.items()

    {:ok, %{users: users, items: items}}
  end

  describe "save event with moderator role" do
    setup [:moderator_1_role, :init_session]

    test "CANNOT save item updated to be unauthorized in the meantime, with reload_on_event? = true",
         %{
           conn: conn
         } do
      # Moderator level 1 can edit items with permission_level <= 1
      {:ok, lv, _html} = live(conn, "/save_event_items/1/edit")

      assigns = get_assigns(lv, SaveEventLoaderLive)
      assert %{loaded_resource: %Item{id: 1, permission_level: 1}} = assigns
      assert :unauthorized not in Map.keys(assigns)

      # Update the resource: make authorization condition broken, expect the save event to fail
      merge_assigns(lv, SaveEventLoaderLive, %{dirty: true})

      # Trigger save event
      lv |> element("#save") |> render_click()

      assigns = get_assigns(lv, SaveEventLoaderLive)
      assert assigns.save_called == true
      assert assigns.save_loaded_resource == nil
      assert :unauthorized in Map.keys(assigns)
    end

    test "CAN save item updated to be unauthorized in the meantime, with reload_on_event? = false",
         %{
           conn: conn
         } do
      # Moderator level 1 can edit items with permission_level <= 1
      {:ok, lv, _html} = live(conn, "/save_event_no_reload_items/1/edit")

      assigns = get_assigns(lv, SaveEventLoaderNoReloadLive)
      assert %{loaded_resource: %Item{id: 1, permission_level: 1}} = assigns
      assert :unauthorized not in Map.keys(assigns)

      # Update the resource: make authorization condition broken, but expect the save event to pass
      merge_assigns(lv, SaveEventLoaderLive, %{dirty: true})

      # Trigger save event
      lv |> element("#save") |> render_click()

      assigns = get_assigns(lv, SaveEventLoaderNoReloadLive)
      assert assigns.save_called == true
      # Unchanged permission level - not reloaded
      assert assigns.save_loaded_resource.permission_level == 1
      assert :unauthorized not in Map.keys(assigns)
    end
  end

  # Helper functions for setting up test roles

  def moderator_1_role(context) do
    {:ok, Map.put(context, :roles, [%{role: :moderator, level: 1}])}
  end

  def init_session(%{roles: roles}) do
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

  defp merge_assigns(lv, live_module, new_assigns) when is_map(new_assigns) do
    live_module.run(lv, fn socket ->
      {:reply, Map.merge(socket.assigns, new_assigns),
       socket |> Phoenix.Component.assign(new_assigns)}
    end)
  end
end
