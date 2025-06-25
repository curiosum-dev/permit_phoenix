defmodule Permit.EctoLiveViewWithLoaderTest do
  @moduledoc false
  use Permit.RepoCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Permit.EctoLiveViewTest.{Endpoint, HooksWithLoaderLive}
  alias Permit.EctoFakeApp.{Item, Repo, User}

  @endpoint Endpoint

  setup do
    %{users: users, items: items} = Repo.seed_data!()

    {:ok, %{users: users, items: items}}
  end

  describe "admin" do
    setup [:admin_role, :init_session]

    test "sets :permit_subject private key", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books")

      private = get_private(lv)

      assert %{permit_subject: %User{id: 1}} = private
    end

    test "can do :index on items", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert Enum.count(assigns[:loaded_resources]) == 3
    end

    test "can do :edit on items", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/1/edit")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert %{loaded_resource: %Item{id: 1}} = assigns
    end

    test "can do :show", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/1")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert %{loaded_resource: %Item{id: 1}} = assigns
    end

    test "can do :new on items", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/new")

      assigns = get_assigns(lv)

      assert :mounted in Map.keys(assigns)
      assert :unauthorized not in Map.keys(assigns)
      assert :loaded_resources not in Map.keys(assigns)
    end

    test "should assign flash error", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/100")

      assigns = get_assigns(lv)
      assert assigns.flash["error"] == "Record not found"
    end
  end

  describe "owner" do
    setup [:owner_role, :init_session]

    test "sets :permit_subject private key", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books")

      private = get_private(lv)

      assert %{permit_subject: %User{id: 1}} = private
    end

    test "can do :index on items", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert Enum.count(assigns[:loaded_resources]) == 1
    end

    test "can do :show on owned item", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/1")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert %{loaded_resource: %Item{id: 1}} = assigns
    end

    test "cannot do :show on non-owned item", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/1")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert %{loaded_resource: %Item{id: 1}} = assigns
    end

    test "can do :edit on owned item", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/1/edit")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert %{loaded_resource: %Item{id: 1}} = assigns
    end

    test "cannot do :edit on non-owned item", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/2/edit")

      assigns = get_assigns(lv)

      assert :unauthorized in Map.keys(assigns)
      refute assigns[:loaded_resources]
      refute assigns[:loaded_resource]
    end

    test "can do :new on items", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/new")

      assigns = get_assigns(lv)

      assert :mounted in Map.keys(assigns)
      assert :unauthorized not in Map.keys(assigns)
      assert :loaded_resources not in Map.keys(assigns)
    end
  end

  describe "inspector" do
    setup [:inspector_role, :init_session]

    test "sets :permit_subject private key", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books")

      private = get_private(lv)

      assert %{permit_subject: %User{id: 1}} = private
    end

    test "can do :index on items", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert Enum.count(assigns[:loaded_resources]) == 3
    end

    test "cannot do :edit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/1/edit")

      assigns = get_assigns(lv)

      assert :unauthorized in Map.keys(assigns)
      refute assigns[:loaded_resources]
      refute assigns[:loaded_resource]
    end

    test "can do :show", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/1")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert %{loaded_resource: %Item{id: 1}} = assigns
    end

    test "cannot do :new on items", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/new")

      assigns = get_assigns(lv)

      assert :unauthorized in Map.keys(assigns)
      assert :loaded_resources not in Map.keys(assigns)
    end
  end

  describe "moderator_1" do
    setup [:moderator_1_role, :init_session]

    test "can do :index on items", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert Enum.count(assigns[:loaded_resources]) == 1
    end

    test "can do :edit on item 1", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/1/edit")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert %{loaded_resource: %Item{id: 1}} = assigns
    end

    test "can do :show on item 1", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/1")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert %{loaded_resource: %Item{id: 1}} = assigns
    end

    test "cant do :edit on item 2", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/2/edit")

      assigns = get_assigns(lv)

      assert :unauthorized in Map.keys(assigns)
      refute assigns[:loaded_resources]
      refute assigns[:loaded_resource]
    end

    test "cant do :show on item 2 ", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/2")

      assigns = get_assigns(lv)

      assert :unauthorized in Map.keys(assigns)
      refute assigns[:loaded_resources]
      refute assigns[:loaded_resource]
    end

    test "cant do :edit on item 3", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/3/edit")

      assigns = get_assigns(lv)

      assert :unauthorized in Map.keys(assigns)
      refute assigns[:loaded_resources]
      refute assigns[:loaded_resource]
    end

    test "cant do :show on item 3", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/3")

      assigns = get_assigns(lv)

      assert :unauthorized in Map.keys(assigns)
      refute assigns[:loaded_resources]
      refute assigns[:loaded_resource]
    end

    test "can do :new on items", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/new")

      assigns = get_assigns(lv)

      assert :mounted in Map.keys(assigns)
      assert :unauthorized not in Map.keys(assigns)
      refute assigns[:loaded_resources]
      refute assigns[:loaded_resource]
    end
  end

  describe "moderator_2" do
    setup [:moderator_2_role, :init_session]

    test "can do :index on items", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert Enum.count(assigns[:loaded_resources]) == 2
    end

    test "can do :edit on item 1", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/1/edit")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert %{loaded_resource: %Item{id: 1}} = assigns
    end

    test "can do :show on item 1", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/1")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert %{loaded_resource: %Item{id: 1}} = assigns
    end

    test "can do :edit on item 2", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/2/edit")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert %{loaded_resource: %Item{id: 2}} = assigns
    end

    test "cant do :show on item 2 ", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/2")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert %{loaded_resource: %Item{id: 2}} = assigns
    end

    test "cant do :edit on item 3", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/3/edit")

      assigns = get_assigns(lv)

      assert :unauthorized in Map.keys(assigns)
      refute assigns[:loaded_resources]
      refute assigns[:loaded_resource]
    end

    test "cant do :show on item 3", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/3")

      assigns = get_assigns(lv)

      assert :unauthorized in Map.keys(assigns)
      refute assigns[:loaded_resources]
      refute assigns[:loaded_resource]
    end

    test "can do :new on items", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/new")

      assigns = get_assigns(lv)

      assert :mounted in Map.keys(assigns)
      assert :unauthorized not in Map.keys(assigns)
      refute assigns[:loaded_resources]
      refute assigns[:loaded_resource]
    end
  end

  describe "thread_moderator" do
    setup [:dmt_thread_moderator_role, :init_session]

    test "can do :index on items", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert Enum.count(assigns[:loaded_resources]) == 1
    end

    test "cant do :edit on item 1", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/1/edit")

      assigns = get_assigns(lv)

      assert :unauthorized in Map.keys(assigns)
      refute assigns[:loaded_resources]
      refute assigns[:loaded_resource]
    end

    test "cant do :show on item 1", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/1")

      assigns = get_assigns(lv)

      assert :unauthorized in Map.keys(assigns)
      refute assigns[:loaded_resources]
      refute assigns[:loaded_resource]
    end

    test "can do :edit on item 2", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/2/edit")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert %{loaded_resource: %Item{id: 2}} = assigns
    end

    test "cant do :show on item 2 ", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/2")

      assigns = get_assigns(lv)

      assert :unauthorized not in Map.keys(assigns)
      assert %{loaded_resource: %Item{id: 2}} = assigns
    end

    test "cant do :edit on item 3", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/3/edit")

      assigns = get_assigns(lv)

      assert :unauthorized in Map.keys(assigns)
      refute assigns[:loaded_resources]
      refute assigns[:loaded_resource]
    end

    test "cant do :show on item 3", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/3")

      assigns = get_assigns(lv)

      assert :unauthorized in Map.keys(assigns)
      refute assigns[:loaded_resources]
      refute assigns[:loaded_resource]
    end

    test "can do :new on items", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books/new")

      assigns = get_assigns(lv)

      assert :mounted in Map.keys(assigns)
      assert :unauthorized not in Map.keys(assigns)
      refute assigns[:loaded_resources]
      refute assigns[:loaded_resource]
    end
  end

  describe "navigation using handle_params" do
    setup [:inspector_role, :init_session]

    test "is successful, authorizes and preloads resource", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books")

      assert (lv |> get_assigns())[:loaded_resources]
      refute (lv |> get_assigns())[:loaded_resource]

      lv |> element("#navigate_show") |> render_click()

      assert %{loaded_resource: %Item{id: 1}, loaded_resource_was_visible_in_handle_params: true} =
               get_assigns(lv)
    end

    test "delegates to unauthorized handler when unauthorized", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/books")

      lv |> element("#navigate_edit") |> render_click()

      assigns = get_assigns(lv)

      refute assigns[:loaded_resources]
      refute assigns[:loaded_resource]
      assert %{unauthorized: true} = assigns
    end
  end

  def admin_role(context) do
    {:ok, Map.put(context, :roles, [:admin])}
  end

  def owner_role(context) do
    {:ok, Map.put(context, :roles, [:owner])}
  end

  def function_owner_role(context) do
    {:ok, Map.put(context, :roles, [:function_owner])}
  end

  def inspector_role(context) do
    {:ok, Map.put(context, :roles, [:inspector])}
  end

  def moderator_1_role(context) do
    {:ok, Map.put(context, :roles, [%{role: :moderator, level: 1}])}
  end

  def moderator_2_role(context) do
    {:ok, Map.put(context, :roles, [%{role: :moderator, level: 2}])}
  end

  def dmt_thread_moderator_role(context) do
    {:ok, Map.put(context, :roles, [%{role: :thread_moderator, thread_name: "dmt"}])}
  end

  def init_session(%{roles: roles}) do
    {:ok,
     conn:
       Plug.Test.init_test_session(
         build_conn(),
         %{"token" => "valid_token", roles: roles}
       )}
  end

  defp get_assigns(lv) do
    HooksWithLoaderLive.run(lv, fn socket -> {:reply, socket.assigns, socket} end)
  end

  defp get_private(lv) do
    HooksWithLoaderLive.run(lv, fn socket -> {:reply, socket.private, socket} end)
  end
end
