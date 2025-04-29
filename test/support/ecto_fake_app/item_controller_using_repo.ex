defmodule Permit.EctoFakeApp.ItemControllerUsingRepo do
  @moduledoc false
  use Phoenix.Controller

  alias Permit.EctoFakeApp.{Authorization, Item}

  use Permit.Phoenix.Controller,
    authorization_module: Authorization,
    resource_module: Item,
    preload_actions: [:show],
    except: [:action_without_authorizing],
    fallback_path: "/?foo"

  def index(conn, _params), do: text(conn, "listing all items")

  def show(conn, _params) do
    text(conn, inspect(conn.assigns[:loaded_resource]))
  end

  def edit(conn, _params), do: text(conn, inspect(conn.assigns[:loaded_resource]))
  def delete(conn, params), do: text(conn, "deleting item #{params["id"]}")
  def details(conn, _params), do: text(conn, inspect(conn.assigns[:loaded_resource]))
  def action_without_authorizing(conn, _params), do: text(conn, "okay")
end
