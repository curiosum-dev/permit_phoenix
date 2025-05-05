defmodule Permit.ActionPlurality.PluralityLiveViewTest do
  @moduledoc false
  use Permit.RepoCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Permit.EctoFakeApp.Repo

  @endpoint Permit.EctoLiveViewTest.Endpoint

  setup do
    %{users: users, items: items} = Repo.seed_data!()
    {:ok, %{users: users, items: items}}
  end

  describe "admin user" do
    setup ctx do
      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Test.init_test_session(token: "valid_token", roles: [:admin])

      {:ok, Map.put(ctx, :conn, conn)}
    end

    test "can list items (plural action)", %{conn: conn} do
      {:ok, _lv, html} = live(conn, "/live_action_plurality")

      # Verify rendering of list view
      assert html =~ "Listing all items"
    end

    test "can view an item (singular action)", %{conn: conn, items: [item | _]} do
      {:ok, _lv, html} = live(conn, "/live_action_plurality/1")

      # Verify rendering of view
      assert html =~ "Viewing item:"
      assert html =~ "id: #{item.id}"
    end
  end

  describe "owner user" do
    setup ctx do
      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Test.init_test_session(token: "valid_token", roles: [:owner])

      {:ok, Map.put(ctx, :conn, conn)}
    end

    test "can list items (plural action)", %{conn: conn} do
      {:ok, _lv, html} = live(conn, "/live_action_plurality")

      # Verify rendering of list view
      assert html =~ "Listing all items"
    end

    test "can view owned item (singular action)", %{conn: conn, items: [item | _]} do
      {:ok, _lv, html} = live(conn, "/live_action_plurality/1")

      # Verify rendering of view
      assert html =~ "Viewing item:"
      assert html =~ "id: #{item.id}"
    end
  end
end
