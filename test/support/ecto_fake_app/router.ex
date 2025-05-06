defmodule Permit.EctoFakeApp.Router do
  @moduledoc false
  use Phoenix.Router

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
end
