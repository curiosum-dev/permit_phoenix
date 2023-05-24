defmodule Permit.EctoLiveViewTest.LiveRouter do
  use Phoenix.Router
  import Phoenix.LiveView.Router
  alias Permit.EctoLiveViewTest.HooksLive

  live_session :authenticated, on_mount: Permit.Phoenix.LiveView.AuthorizeHook do
    live("/items", HooksLive, :index)
    live("/items/new", HooksLive, :new)
    live("/items/:id/edit", HooksLive, :edit)
    live("/items/:id", HooksLive, :show)
  end

  def session(%Plug.Conn{}, extra), do: Map.merge(extra, %{"called" => true})
end
