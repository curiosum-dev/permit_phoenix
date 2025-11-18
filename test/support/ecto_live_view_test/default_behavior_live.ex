defmodule Permit.EctoLiveViewTest.DefaultBehaviorLive do
  @moduledoc """
  A LiveView that uses all default behaviors from Permit.Phoenix.LiveView,
  specifically for testing handle_unauthorized and fallback_path with _live_referer.
  """
  use Phoenix.LiveView, namespace: Permit

  alias Permit.EctoFakeApp.{Authorization, Item}

  use Permit.Phoenix.LiveView,
    authorization_module: Authorization,
    resource_module: Item

  @impl true
  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div>
      <button id="navigate_show" phx-click="navigate" phx-value-url="/default_items/1">show</button>
      <button id="navigate_edit" phx-click="navigate" phx-value-url="/default_items/1/edit">edit</button>
      <button id="delete" phx-click="delete" phx-value-id="2">delete</button>
      <button id="update" phx-click="update" phx-value-id="2">update</button>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, mounted: true)}
  end

  @impl true
  def handle_event("navigate", %{"url" => url}, socket) do
    {:noreply, push_patch(socket, to: url)}
  end

  @impl true
  def handle_event("delete", %{"id" => _id}, socket) do
    # Delete action - will trigger authorization check via AuthorizeHook
    {:noreply, socket}
  end

  @impl true
  def handle_event("update", %{"id" => _id}, socket) do
    # Update action - will trigger authorization check via AuthorizeHook
    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_call({:run, func}, _, socket), do: func.(socket)

  @impl true
  def handle_info({:run, func}, socket), do: func.(socket)

  def run(lv, func) do
    GenServer.call(lv.pid, {:run, func})
  end
end
