defmodule Permit.EctoLiveViewTest.LiveRouter do
  @moduledoc false
  use Phoenix.Router

  import Phoenix.LiveView.Router

  alias Permit.EctoFakeApp.ActionPluralityLive
  alias Permit.EctoLiveViewTest.HooksWithLoaderLive
  alias Permit.EctoLiveViewTest.HooksLive
  alias Permit.EctoLiveViewTest.HooksWithCustomOptsLive
  alias Permit.EctoLiveViewTest.DefaultBehaviorLive
  alias Permit.EctoLiveViewTest.SaveEventLive
  alias Permit.EctoLiveViewTest.SaveEventNoReloadLive

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

      live("/default_items", DefaultBehaviorLive, :index)
      live("/default_items/new", DefaultBehaviorLive, :new)
      live("/default_items/:id/edit", DefaultBehaviorLive, :edit)
      live("/default_items/:id", DefaultBehaviorLive, :show)

      live("/save_event_items/:id/edit", SaveEventLive, :edit)
      live("/save_event_no_reload_items/:id/edit", SaveEventNoReloadLive, :edit)
    end
  end

  def session(%Plug.Conn{}, extra), do: Map.merge(extra, %{"called" => true})
end
