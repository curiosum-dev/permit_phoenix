defmodule Permit.EctoLiveViewTest.LiveRouter do
  @moduledoc false
  use Phoenix.Router

  import Phoenix.LiveView.Router

  alias Permit.EctoFakeApp.ActionPluralityLive
  alias Permit.EctoLiveViewTest.HooksWithLoaderLive
  alias Permit.EctoLiveViewTest.HooksLive
  alias Permit.EctoLiveViewTest.HooksWithCustomOptsLive

  scope "/" do
    live_session :authenticated,
      on_mount: [
        {Permit.EctoLiveViewTest.UserAuth, :mount_current_scope},
        Permit.Phoenix.LiveView.AuthorizeHook
      ] do
      live("/items", HooksLive, :index)
      live("/items/new", HooksLive, :new)
      live("/items/:id/edit", HooksLive, :edit)
      live("/items/:id", HooksLive, :show)

      live("/items_custom/:id/edit", HooksWithCustomOptsLive, :edit)

      live("/books", HooksWithLoaderLive, :index)
      live("/books/new", HooksWithLoaderLive, :new)
      live("/books/:id/edit", HooksWithLoaderLive, :edit)
      live("/books/:id", HooksWithLoaderLive, :show)

      live("/live_action_plurality", ActionPluralityLive, :list)
      live("/live_action_plurality/:id", ActionPluralityLive, :view)
    end
  end

  def session(%Plug.Conn{}, extra), do: Map.merge(extra, %{"called" => true})
end
