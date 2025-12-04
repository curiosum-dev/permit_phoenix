defmodule Permit.EctoLiveViewTest.SaveEventLive do
  @moduledoc """
  LiveView for testing handle_event with "save" events that contain form payloads
  instead of IDs. Tests both reload_on_event? behaviors.
  """
  use Phoenix.LiveView, namespace: Permit

  alias Permit.EctoFakeApp.{Authorization, Item}

  use Permit.Phoenix.LiveView,
    authorization_module: Authorization,
    resource_module: Item

  @impl Permit.Phoenix.LiveView
  def handle_unauthorized(_action, socket), do: {:cont, assign(socket, :unauthorized, true)}

  @impl true
  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id="item-form">
      <button id="save" phx-click="save" phx-value-permission_level="5">Save</button>
      <button id="cancel" phx-click="cancel">Cancel</button>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, mounted: true)}
  end

  @impl true
  @permit_action :update
  def handle_event("save", params, socket) do
    # Store the params and loaded_resource for test verification
    socket =
      socket
      |> assign(:save_called, true)
      |> assign(:save_params, params)
      |> assign(:save_loaded_resource, socket.assigns[:loaded_resource])

    {:noreply, socket}
  end

  def handle_event("cancel", _params, socket) do
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
