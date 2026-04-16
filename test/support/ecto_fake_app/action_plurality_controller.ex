defmodule Permit.EctoFakeApp.ActionPluralityController do
  @moduledoc false
  use Phoenix.Controller, formats: [html: "View"]

  alias Permit.EctoFakeApp.{Authorization, Item}

  use Permit.Phoenix.Controller,
    authorization_module: Authorization,
    resource_module: Item

  def list(conn, _params), do: text(conn, "listing all items")
  def view(conn, _params), do: text(conn, inspect(conn.assigns[:loaded_resource]))
  def index(conn, _params), do: text(conn, "index by date")
  def show(conn, _params), do: text(conn, inspect(conn.assigns[:loaded_resource]))
  def custom_view(conn, _params), do: text(conn, inspect(conn.assigns[:loaded_resource]))
  def feed(conn, _params), do: text(conn, "feed")

  @impl true
  def singular_actions, do: [:view]

  @impl true
  def plural_actions, do: super() ++ [:feed]
end
