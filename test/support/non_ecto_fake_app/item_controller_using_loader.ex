defmodule Permit.NonEctoFakeApp.ItemControllerUsingLoader do
  use Phoenix.Controller

  alias Permit.NonEctoFakeApp.{Authorization, Item, NoResultsError}

  use Permit.Phoenix.Controller,
    authorization_module: Authorization,
    loader: &__MODULE__.preload/4,
    resource_module: Item

  def index(conn, _params), do: text(conn, "listing all items")
  def show(conn, _params), do: text(conn, inspect(conn.assigns[:loaded_resource]))

  @item1 %Item{id: 1, owner_id: 1, permission_level: 1}
  @item2 %Item{id: 2, owner_id: 2, permission_level: 2}
  @item3 %Item{id: 3, owner_id: 3, permission_level: 3}

  def preload(:index, Item, _user, _params), do: [@item1, @item2, @item3]

  def preload(_action, Item, _user, %{"id" => "1"}), do: @item1
  def preload(_action, Item, _user, %{"id" => "2"}), do: @item2
  def preload(_action, Item, _user, %{"id" => "3"}), do: @item3

  def preload(_action, _object, _user, _params), do: raise(NoResultsError)
end
