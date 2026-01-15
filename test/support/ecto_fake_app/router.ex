defmodule Permit.EctoFakeApp.Router do
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

  pipeline :browser do
    plug(Plug.Session,
      store: :cookie,
      key: "_example_key",
      signing_salt: "8ixXSdpw"
    )

    plug(:fetch_session)
    plug(:fetch_flash)
  end

  scope "/" do
    pipe_through(:browser)

    post("/sign_in", Permit.EctoFakeApp.SessionController, :create)
    resources("/items", Permit.EctoFakeApp.ItemControllerUsingRepo)
    resources("/blogs", Permit.EctoFakeApp.ItemControllerUsingRepoWithLoader)

    get("/details/:id", Permit.EctoFakeApp.ItemControllerUsingRepo, :show)
    get("/account/:id", Permit.EctoFakeApp.ItemControllerUsingRepoWithLoader, :show)

    resources("/items_custom", Permit.EctoFakeApp.ItemControllerUsingRepoWithCustomOpts)

    get(
      "/action_without_authorizing",
      Permit.EctoFakeApp.ItemControllerUsingRepo,
      :action_without_authorizing
    )
  end

  scope "/action_plurality" do
    pipe_through(:browser)

    get("/", Permit.EctoFakeApp.ActionPluralityController, :list)
    get("/:id", Permit.EctoFakeApp.ActionPluralityController, :view)
  end

  ## Live routes testing
  scope "/live" do
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
end
