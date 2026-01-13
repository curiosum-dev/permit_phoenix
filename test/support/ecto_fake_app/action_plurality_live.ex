defmodule Permit.EctoFakeApp.ActionPluralityLive do
  @moduledoc false
  use Phoenix.LiveView, namespace: Permit

  alias Permit.EctoFakeApp.{Authorization, Item, User}

  use Permit.Phoenix.LiveView,
    authorization_module: Authorization,
    resource_module: Item,
    preload_actions: [:view, :list]

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @live_action == :list do %>
        <div id="list">Listing all items</div>
      <% else %>
        <div id="view">Viewing item: <%= inspect(@loaded_resource) %></div>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def fetch_subject(_socket, session) do
    case session["token"] do
      "valid_token" -> %User{id: 1, roles: session["roles"] || []}
      _ -> nil
    end
  end

  # To test that the action is considered plural by default, we have commented out the explicit declaration
  # of the :view action as singular.
  #
  # action_plurality_controller.ex implements this callback with an explicit declaration to test it out, too.

  # @impl true
  # def singular_actions, do: [:view]
end
