defmodule Permit.EctoTransactionLiveViewTest do
  @moduledoc """
  Tests for authorize_with_transaction in LiveView handle_event.
  Mirrors the Controller authorize_with_transaction tests for LiveView context.
  """
  use Permit.RepoCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Permit.EctoFakeApp.{Item, Repo}
  alias Permit.EctoLiveViewTest.{Endpoint, TransactionLive}

  @endpoint Endpoint

  setup do
    %{users: users, items: items} = Repo.seed_data!()

    {:ok, %{users: users, items: items}}
  end

  describe "admin creates any item" do
    setup [:admin_role, :init_session]

    test "admin creates item with any owner_id", %{conn: conn} do
      {:ok, liveview, _html} = live(conn, "/live/transaction_items/new")

      liveview
      |> element("#save")
      |> render_click(%{
        "item" => %{"owner_id" => "2", "permission_level" => "7"}
      })

      assigns = get_assigns(liveview)
      assert %Item{owner_id: 2, permission_level: 7} = assigns.created_item
      assert Repo.get_by(Item, owner_id: 2, permission_level: 7)
    end
  end

  describe "creator creates item" do
    setup [:creator_role, :init_session]

    test "creator creates item with matching owner_id", %{conn: conn} do
      {:ok, liveview, _html} = live(conn, "/live/transaction_items/new")

      liveview
      |> element("#save")
      |> render_click(%{
        "item" => %{"owner_id" => "1", "permission_level" => "5"}
      })

      assigns = get_assigns(liveview)
      assert %Item{owner_id: 1, permission_level: 5} = assigns.created_item
      assert Repo.get_by(Item, owner_id: 1, permission_level: 5)
    end

    test "creator creates item with wrong owner_id, unauthorized, rolled back", %{conn: conn} do
      {:ok, liveview, _html} = live(conn, "/live/transaction_items/new")

      liveview
      |> element("#save")
      |> render_click(%{
        "item" => %{"owner_id" => "2", "permission_level" => "5"}
      })

      assigns = get_assigns(liveview)
      assert assigns[:unauthorized] == true
      refute Map.has_key?(assigns, :created_item)
      refute Repo.get_by(Item, owner_id: 2, permission_level: 5)
    end
  end

  describe "validation error" do
    setup [:admin_role, :init_session]

    test "validation error passes through", %{conn: conn} do
      {:ok, liveview, _html} = live(conn, "/live/transaction_items/new")

      liveview
      |> element("#save")
      |> render_click(%{
        "item" => %{"permission_level" => "not_a_number"}
      })

      assigns = get_assigns(liveview)
      assert %Ecto.Changeset{} = assigns.changeset_error
      refute Map.has_key?(assigns, :created_item)
    end
  end

  describe "action override" do
    setup [:creator_role, :init_session]

    test "creator denied when action is overridden to update", %{conn: conn} do
      {:ok, liveview, _html} = live(conn, "/live/transaction_items/new")

      liveview
      |> element("#save")
      |> render_click(%{
        "_authorize_as" => "update",
        "item" => %{"owner_id" => "1", "permission_level" => "9"}
      })

      assigns = get_assigns(liveview)
      assert assigns[:unauthorized] == true
      refute Map.has_key?(assigns, :created_item)
      refute Repo.get_by(Item, owner_id: 1, permission_level: 9)
    end
  end

  describe "action override with owner role" do
    setup [:owner_role, :init_session]

    test "owner succeeds when action is overridden to update with matching owner_id", %{
      conn: conn
    } do
      {:ok, liveview, _html} = live(conn, "/live/transaction_items/new")

      liveview
      |> element("#save")
      |> render_click(%{
        "_authorize_as" => "update",
        "item" => %{"owner_id" => "1", "permission_level" => "9"}
      })

      assigns = get_assigns(liveview)
      assert %Item{owner_id: 1, permission_level: 9} = assigns.created_item
      assert Repo.get_by(Item, owner_id: 1, permission_level: 9)
    end

    test "owner denied when action is overridden to update with wrong owner_id", %{conn: conn} do
      {:ok, liveview, _html} = live(conn, "/live/transaction_items/new")

      liveview
      |> element("#save")
      |> render_click(%{
        "_authorize_as" => "update",
        "item" => %{"owner_id" => "2", "permission_level" => "9"}
      })

      assigns = get_assigns(liveview)
      assert assigns[:unauthorized] == true
      refute Map.has_key?(assigns, :created_item)
      refute Repo.get_by(Item, owner_id: 2, permission_level: 9)
    end
  end

  describe "on_unauthorized option" do
    setup [:creator_role, :init_session]

    test "on_unauthorized option overrides default handler", %{conn: conn} do
      {:ok, liveview, _html} = live(conn, "/live/transaction_items/new")

      liveview
      |> element("#save")
      |> render_click(%{
        "_custom_unauthorized" => "true",
        "item" => %{"owner_id" => "2", "permission_level" => "5"}
      })

      assigns = get_assigns(liveview)
      assert assigns[:custom_unauthorized] == true
      # Default handler should NOT have been called
      refute Map.has_key?(assigns, :unauthorized)
      refute Repo.get_by(Item, owner_id: 2, permission_level: 5)
    end
  end

  describe "admin action override to update" do
    setup [:admin_role, :init_session]

    test "admin succeeds when action is overridden to update", %{conn: conn} do
      {:ok, liveview, _html} = live(conn, "/live/transaction_items/new")

      liveview
      |> element("#save")
      |> render_click(%{
        "_authorize_as" => "update",
        "item" => %{"owner_id" => "2", "permission_level" => "9"}
      })

      assigns = get_assigns(liveview)
      assert %Item{owner_id: 2, permission_level: 9} = assigns.created_item
      assert Repo.get_by(Item, owner_id: 2, permission_level: 9)
    end
  end

  describe "subject option" do
    setup [:admin_role, :init_session]

    test "subject option overrides default subject resolution", %{conn: conn} do
      # User 1 is logged in (admin), but we override subject to User{id: 2, roles: [:creator]}.
      # :creator has create(Item, owner_id: user.id), so subject User{id: 2}
      # can only create items with owner_id: 2.
      {:ok, liveview, _html} = live(conn, "/live/transaction_items/new")

      # Create item with owner_id: 2, subject overridden to user 2 - should succeed
      liveview
      |> element("#save")
      |> render_click(%{
        "_subject_id" => "2",
        "item" => %{"owner_id" => "2", "permission_level" => "3"}
      })

      assigns = get_assigns(liveview)
      assert %Item{owner_id: 2, permission_level: 3} = assigns.created_item
      assert Repo.get_by(Item, owner_id: 2, permission_level: 3)
    end

    test "subject option - unauthorized when subject doesn't match", %{conn: conn} do
      # Override subject to User{id: 2, roles: [:creator]}, but try owner_id: 1
      {:ok, liveview, _html} = live(conn, "/live/transaction_items/new")

      liveview
      |> element("#save")
      |> render_click(%{
        "_subject_id" => "2",
        "item" => %{"owner_id" => "1", "permission_level" => "3"}
      })

      assigns = get_assigns(liveview)
      assert assigns[:unauthorized] == true
      refute Map.has_key?(assigns, :created_item)
      refute Repo.get_by(Item, owner_id: 1, permission_level: 3)
    end
  end

  # Helper functions

  defp admin_role(context) do
    {:ok, Map.put(context, :roles, [:admin])}
  end

  defp creator_role(context) do
    {:ok, Map.put(context, :roles, [:creator])}
  end

  defp owner_role(context) do
    {:ok, Map.put(context, :roles, [:owner])}
  end

  defp init_session(%{roles: roles}) do
    {:ok,
     conn:
       Plug.Test.init_test_session(
         build_conn(),
         %{"token" => "valid_token", roles: roles}
       )}
  end

  defp get_assigns(liveview) do
    TransactionLive.run(liveview, fn socket -> {:reply, socket.assigns, socket} end)
  end
end
