defmodule Permit.EctoFakeApp.ItemControllerUsingRepo do
  @moduledoc false
  require Logger

  use Phoenix.Controller

  alias Permit.EctoFakeApp.{Authorization, Item, User}

  use Permit.Phoenix.Controller,
    authorization_module: Authorization,
    resource_module: Item,
    preload_actions: [:show],
    except: [:action_without_authorizing],
    fallback_path: "/?foo"

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  @resource_module User
  def index(conn, _params), do: text(conn, "listing all users")

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  @resource_module Item
  def show(conn, _params) do
    text(conn, inspect(conn.assigns[:loaded_resource]))
  end

  def edit(conn, _params), do: text(conn, inspect(conn.assigns[:loaded_resource]))

  def details(conn, _params), do: text(conn, inspect(conn.assigns[:loaded_resource]))
  def action_without_authorizing(conn, _params), do: text(conn, "okay")
end
