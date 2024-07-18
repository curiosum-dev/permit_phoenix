defmodule Permit.EctoFakeApp.ItemControllerUsingRepoWithCustomOpts do
  @moduledoc false
  use Phoenix.Controller

  alias Permit.EctoFakeApp.{Authorization, Item}

  use Permit.Phoenix.Controller,
    authorization_module: Authorization,
    resource_module: Item,
    preload_actions: [:show],
    except: [:action_without_authorizing]

  def index(conn, _params), do: text(conn, "listing all items")
  def show(conn, _params), do: text(conn, inspect(conn.assigns[:loaded_resource]))
  def edit(conn, _params), do: text(conn, inspect(conn.assigns[:loaded_resource]))
  def delete(conn, params), do: text(conn, "deleting item #{params["id"]}")
  def details(conn, _params), do: text(conn, inspect(conn.assigns[:loaded_resource]))
  def action_without_authorizing(conn, _params), do: text(conn, "okay")

  @impl true
  def unauthorized_message(_action, _conn) do
    "Lorem ipsum."
  end

  @impl true
  def fallback_path(_action, _conn) do
    "/?foo"
  end
end
