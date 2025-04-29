defmodule Permit.EctoFakeApp.ActionPluralityController do
  @moduledoc false
  use Phoenix.Controller

  alias Permit.EctoFakeApp.{Authorization, Item}

  use Permit.Phoenix.Controller,
    authorization_module: Authorization,
    resource_module: Item,
    preload_actions: [:view, :list]

  def list(conn, _params), do: text(conn, "listing all items")
  def view(conn, _params), do: text(conn, inspect(conn.assigns[:loaded_resource]))

  @impl true
  def singular_actions, do: [:view]
end
