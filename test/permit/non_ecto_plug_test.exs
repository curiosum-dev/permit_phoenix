defmodule Permit.NonEctoPlugTest do
  use Permit.RepoCase, async: true
  use Permit.NonEctoPlugTest.RouterHelper

  alias Permit.NonEctoFakeApp.{
    Item,
    RouterUsingLoader
  }

  describe "admin, using loader function instead of repo" do
    setup do
      %{
        conn: create_conn(RouterUsingLoader, :post, "/sign_in", %{id: 1, roles: [:admin]})
      }
    end

    test "authorizes :index action", %{conn: conn} do
      conn = call(conn, :get, "/items")
      assert conn.resp_body == "listing all items"
    end

    test "authorizes :show action", %{conn: conn} do
      conn = call(conn, :get, "/items/1")
      assert conn.resp_body =~ ~r[Item]
      assert %Item{id: 1} = conn.assigns[:loaded_resource]
    end

    test "raises when record does not exist", %{conn: conn} do
      assert_raise Plug.Conn.WrapperError, ~r/NoResultsError/, fn ->
        call(conn, :get, "/items/0")
      end
    end
  end

  defp create_conn(router, verb, path, params) do
    router
    |> call(verb, path, params)
    |> Map.put(:secret_key_base, secret_key_base())
  end

  defp secret_key_base do
    :crypto.strong_rand_bytes(64) |> Base.encode64(padding: false) |> binary_part(0, 64)
  end
end
