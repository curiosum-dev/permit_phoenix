defmodule Permit.EctoLiveViewTest.UserAuth do
  @moduledoc false
  import Plug.Conn

  alias Permit.EctoFakeApp.Scope
  alias Permit.EctoFakeApp.User

  # Mimic default scope fetching process of Phoenix 1.8+
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  # TODO: This might only be needed for Plug-based controllers, not LiveViews. If so, move this file to ecto_fake_app,
  # because it'll be used by Plug tests as well.
  def fetch_current_scope_for_user(conn, _opts) do
    session = get_session(conn)

    user = user_from_session(session)

    conn
    |> assign(:current_scope, Scope.for_user(user))
  end

  def mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      user = user_from_session(session)
      Scope.for_user(user)
    end)
  end

  def user_from_session(session) do
    case session["token"] do
      "valid_token" -> %User{id: 1, roles: session["roles"] || []}
      _ -> nil
    end
  end
end
