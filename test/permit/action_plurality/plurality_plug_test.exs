defmodule Permit.Phoenix.ActionPlurality.PluralityPlugTest do
  use Permit.RepoCase, async: true
  use Permit.EctoPlugTest.RouterHelper

  alias Permit.EctoFakeApp.{Item, Repo, Router}

  setup do
    %{users: users, items: items} = Repo.seed_data!()

    {:ok, %{users: users, items: items}}
  end

  describe "singular actions" do
    setup do
      %{conn: create_conn(Router, :post, "/sign_in", %{id: 1, roles: [:owner]})}
    end

    test "returns the resource when the action is singular", %{conn: conn} do
      conn =
        conn
        |> call(:get, "/action_plurality/1")

      assert %Item{} = conn.assigns[:loaded_resource]
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
