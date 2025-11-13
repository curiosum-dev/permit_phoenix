defmodule Permit.EctoLiveViewTest.UserAuth do
  @moduledoc false

  alias Permit.EctoFakeApp.Scope
  alias Permit.EctoFakeApp.User

  # Mimic default scope fetching process of Phoenix 1.8+
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
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
