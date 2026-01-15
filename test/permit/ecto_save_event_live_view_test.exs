defmodule Permit.EctoSaveEventLiveViewTest do
  @moduledoc """
  Tests for LiveView handle_event authorization with "save" events that contain
  form payloads instead of IDs. Tests both reload_on_event? behaviors:
  - reload_on_event? = true (default): reloads the resource before authorization
  - reload_on_event? = false: uses the already loaded resource from assigns
  """
  use Permit.RepoCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Permit.EctoLiveViewTest.{Endpoint, SaveEventLive, SaveEventNoReloadLive}
  alias Permit.EctoFakeApp.{Item, Repo}

  @endpoint Endpoint

  setup do
    %{users: users, items: items} = Repo.seed_data!()

    {:ok, %{users: users, items: items}}
  end

  describe "save event with owner role, reload_on_event? = true (default)" do
    setup [:owner_role, :init_session]

    test "can save owned item - reloads resource and authorizes", %{conn: conn} do
      # Navigate to edit page for item 1 (owned by user 1)
      {:ok, lv, _html} = live(conn, "/live/save_event_items/1/edit")

      # Verify the resource was loaded on mount
      assigns = get_assigns(lv, SaveEventLive)
      assert %{loaded_resource: %Item{id: 1}} = assigns
      assert :unauthorized not in Map.keys(assigns)

      # Update resource to check if it is reloaded later
      initial_resource = assigns[:loaded_resource]
      initial_resource |> Ecto.Changeset.change(%{thread_name: "updated"}) |> Repo.update!()

      # Trigger save event with form payload (no ID in params)
      lv |> element("#save") |> render_click()

      # Verify the event was processed and resource was reloaded
      assigns = get_assigns(lv, SaveEventLive)
      assert assigns.save_called == true
      assert assigns.save_params["permission_level"] == "5"
      # The loaded_resource should still be present (reloaded)
      assert %Item{id: 1} = assigns.save_loaded_resource
      assert assigns.save_loaded_resource.thread_name == "updated"
      assert :unauthorized not in Map.keys(assigns)
    end

    test "reloads resource on each save event", %{conn: conn} do
      # Navigate to edit page for item 1
      {:ok, lv, _html} = live(conn, "/live/save_event_items/1/edit")

      # Get initial loaded resource
      initial_assigns = get_assigns(lv, SaveEventLive)
      initial_resource = initial_assigns.loaded_resource

      # Update resource to check if it is reloaded later
      initial_resource |> Ecto.Changeset.change(%{thread_name: "updated"}) |> Repo.update!()

      # Trigger save event
      lv |> element("#save") |> render_click()

      # Get the resource that was present during save
      save_assigns = get_assigns(lv, SaveEventLive)
      save_resource = save_assigns.save_loaded_resource

      # Both should be the same item (reloaded from DB)
      assert initial_resource.id == save_resource.id
      assert save_resource.id == 1
      assert save_resource.thread_name == "updated"
    end
  end

  describe "save event with owner role, reload_on_event? = false" do
    setup [:owner_role, :init_session]

    test "can save owned item - uses preloaded resource without reload", %{conn: conn} do
      # Navigate to edit page for item 1 (owned by user 1)
      {:ok, lv, _html} = live(conn, "/live/save_event_no_reload_items/1/edit")

      # Verify the resource was loaded on mount
      assigns = get_assigns(lv, SaveEventNoReloadLive)
      assert %{loaded_resource: %Item{id: 1}} = assigns
      assert :unauthorized not in Map.keys(assigns)

      # Update the resource: make authorization condition broken, but expect the save event to succeed
      initial_resource = assigns.loaded_resource
      initial_resource |> Ecto.Changeset.change(%{thread_name: "broken"}) |> Repo.update!()

      # Trigger save event with form payload (no ID in params)
      lv |> element("#save") |> render_click()

      # Verify the event was processed using the preloaded resource
      assigns = get_assigns(lv, SaveEventNoReloadLive)
      assert assigns.save_called == true
      assert assigns.save_params["permission_level"] == "5"
      # The loaded_resource should be the same one from mount (not reloaded)
      assert %Item{id: 1} = assigns.save_loaded_resource
      assert assigns.save_loaded_resource.thread_name != "broken"
      assert :unauthorized not in Map.keys(assigns)
    end
  end

  describe "save event with moderator role" do
    setup [:moderator_1_role, :init_session]

    test "CANNOT save item updated to be unauthorized in the meantime, with reload_on_event? = true",
         %{
           conn: conn
         } do
      # Moderator level 1 can edit items with permission_level <= 1
      {:ok, lv, _html} = live(conn, "/live/save_event_items/1/edit")

      assigns = get_assigns(lv, SaveEventLive)
      assert %{loaded_resource: %Item{id: 1, permission_level: 1}} = assigns
      assert :unauthorized not in Map.keys(assigns)

      # Update the resource: make authorization condition broken, expect the save event to fail
      initial_resource = assigns.loaded_resource
      initial_resource |> Ecto.Changeset.change(%{permission_level: 100}) |> Repo.update!()

      # Trigger save event
      lv |> element("#save") |> render_click()

      assigns = get_assigns(lv, SaveEventLive)
      assert assigns.save_called == true
      assert assigns.save_loaded_resource == nil
      assert :unauthorized in Map.keys(assigns)
    end

    test "CAN save item updated to be unauthorized in the meantime, with reload_on_event? = false",
         %{
           conn: conn
         } do
      # Moderator level 1 can edit items with permission_level <= 1
      {:ok, lv, _html} = live(conn, "/live/save_event_no_reload_items/1/edit")

      assigns = get_assigns(lv, SaveEventNoReloadLive)
      assert %{loaded_resource: %Item{id: 1, permission_level: 1}} = assigns
      assert :unauthorized not in Map.keys(assigns)

      # Trigger save event
      lv |> element("#save") |> render_click()

      assigns = get_assigns(lv, SaveEventNoReloadLive)
      assert assigns.save_called == true
      assert assigns.save_loaded_resource.permission_level == 1
      assert :unauthorized not in Map.keys(assigns)
    end
  end

  # Helper functions for setting up test roles

  def owner_role(context) do
    {:ok, Map.put(context, :roles, [:owner])}
  end

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
end
