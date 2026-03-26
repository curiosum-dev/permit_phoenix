defmodule Permit.EctoLiveViewTest.ExceptLive do
  @moduledoc """
  LiveView for testing except/0 callback in the authorization hook.
  The :index action is excepted from authorization.
  """
  use Phoenix.LiveView, namespace: Permit

  alias Permit.EctoFakeApp.{Authorization, Item}
  alias Permit.EctoFakeApp.Item.Context

  use Permit.Phoenix.LiveView,
    authorization_module: Authorization,
    resource_module: Item

  @impl Permit.Phoenix.LiveView
  def except, do: [:index]

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
    <div>except live</div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, mounted: true)}
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
