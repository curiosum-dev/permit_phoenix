defmodule Permit.EctoLiveViewTest.LoadAndAuthorizeLive do
  @moduledoc """
  LiveView for testing load_and_authorize/5 public function.
  Loads resources via load_and_authorize in handle_event handlers.
  """
  use Phoenix.LiveView, namespace: Permit

  alias Permit.EctoFakeApp.{Authorization, Item}
  alias Permit.EctoFakeApp.Item.Context

  use Permit.Phoenix.LiveView,
    authorization_module: Authorization,
    resource_module: Item

  @impl Permit.Phoenix.LiveView
  def base_query(%{resource_module: Item, params: params}) do
    case params do
      %{"id" => id} ->
        id = if is_bitstring(id), do: String.to_integer(id), else: id
        Context.filter_by_id(Item, id)

      %{} ->
        Item
    end
  end

  @impl Permit.Phoenix.LiveView
  def handle_unauthorized(_action, socket),
    do: {:cont, assign(socket, :unauthorized, true)}

  @impl true
  def render(assigns) do
    ~H"""
    <button id="load_one" phx-click="load_one" phx-value-id="1">Load One</button>
    <button id="load_all" phx-click="load_all">Load All</button>
    <button id="load_nonexistent" phx-click="load_one" phx-value-id="0">Load Nonexistent</button>
    <button id="edit_one" phx-click="edit_one" phx-value-id="1">Edit One</button>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, mounted: true)}
  end

  @impl true
  def handle_event("load_one", params, socket) do
    case load_and_authorize(socket, :show, Item, params) do
      {:authorized, record} ->
        {:noreply, assign(socket, :manual_resource, record)}

      :unauthorized ->
        {:noreply, assign(socket, :manual_unauthorized, true)}

      :not_found ->
        {:noreply, assign(socket, :manual_not_found, true)}
    end
  end

  def handle_event("load_all", _params, socket) do
    case load_and_authorize(socket, :index, Item, %{}) do
      {:authorized, records} ->
        {:noreply, assign(socket, :manual_resources, records)}

      :unauthorized ->
        {:noreply, assign(socket, :manual_unauthorized, true)}
    end
  end

  def handle_event("edit_one", params, socket) do
    case load_and_authorize(socket, :edit, Item, params) do
      {:authorized, record} ->
        {:noreply, assign(socket, :manual_edit_resource, record)}

      :unauthorized ->
        {:noreply, assign(socket, :manual_edit_unauthorized, true)}

      :not_found ->
        {:noreply, assign(socket, :manual_not_found, true)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_call({:run, func}, _, socket), do: func.(socket)

  @impl true
  def handle_info({:run, func}, socket), do: func.(socket)

  def run(lv, func), do: GenServer.call(lv.pid, {:run, func})
end
