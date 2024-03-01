defmodule Permit.EctoFakeApp.ItemControllerUsingRepoWithLoader do
  @moduledoc false
  use Phoenix.Controller

  alias Permit.EctoFakeApp.{Authorization, Item, NoResultsError}

  use Permit.Phoenix.Controller,
    authorization_module: Authorization,
    resource_module: Item,
    preload_actions: [:show],
    except: [:action_without_authorizing],
    fallback_path: "/?foo",
    use_loader?: true

  @item1 %Item{id: 1, owner_id: 1, permission_level: 1}
  @item2 %Item{id: 2, owner_id: 2, permission_level: 2, thread_name: "dmt"}
  @item3 %Item{id: 3, owner_id: 3, permission_level: 3}

  def loader(%{action: :index}), do: [@item1, @item2, @item3]
  def loader(%{params: %{"id" => "1"}}), do: @item1
  def loader(%{params: %{"id" => "2"}}), do: @item2
  def loader(%{params: %{"id" => "3"}}), do: @item3
  def loader(_), do: raise(NoResultsError)

  def index(conn, _params), do: text(conn, "listing all items")
  def show(conn, _params), do: text(conn, inspect(conn.assigns[:loaded_resource]))
  def edit(conn, _params), do: text(conn, inspect(conn.assigns[:loaded_resource]))
  def details(conn, _params), do: text(conn, inspect(conn.assigns[:loaded_resource]))
  def action_without_authorizing(conn, _params), do: text(conn, "okay")
end
