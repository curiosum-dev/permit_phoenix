defmodule Permit.NonEctoLiveViewTest.LiveRouter do
  @moduledoc false
  use Phoenix.Router
  import Phoenix.LiveView.Router
  alias Permit.NonEctoLiveViewTest.HooksLive
  alias Permit.NonEctoLiveViewTest.SaveEventLoaderLive
  alias Permit.NonEctoLiveViewTest.SaveEventLoaderNoReloadLive

  live_session :authenticated, on_mount: Permit.Phoenix.LiveView.AuthorizeHook do
    live("/items", HooksLive, :index)
    live("/items/new", HooksLive, :new)
    live("/items/:id/edit", HooksLive, :edit)
    live("/items/:id", HooksLive, :show)

    live("/save_event_items/:id/edit", SaveEventLoaderLive, :edit)
    live("/save_event_no_reload_items/:id/edit", SaveEventLoaderNoReloadLive, :edit)
  end

  def session(%Plug.Conn{}, extra), do: Map.merge(extra, %{"called" => true})
end
