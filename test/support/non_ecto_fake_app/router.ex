defmodule Permit.NonEctoFakeApp.Router do
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

    post("/sign_in", Permit.NonEctoFakeApp.SessionController, :create)
  end
end
