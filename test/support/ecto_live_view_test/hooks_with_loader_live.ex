defmodule Permit.EctoLiveViewTest.HooksWithLoaderLive do
  use Phoenix.LiveView, namespace: Permit

  alias Permit.EctoFakeApp.{Authorization, Item, User}

  use Permit.Phoenix.LiveView,
    authorization_module: Authorization,
    resource_module: Item,
    use_loader?: true

  @item1 %Item{id: 1, owner_id: 1, permission_level: 1}
  @item2 %Item{id: 2, owner_id: 2, permission_level: 2, thread_name: "dmt"}
  @item3 %Item{id: 3, owner_id: 3, permission_level: 3}

  def loader(%{action: :index}), do: [@item1, @item2, @item3]
  def loader(%{params: %{"id" => "1"}}), do: @item1
  def loader(%{params: %{"id" => "2"}}), do: @item2
  def loader(%{params: %{"id" => "3"}}), do: @item3
  def loader(_), do: nil

  def handle_not_found(socket) do
    {:cont, put_flash(socket, :error, "Record not found")}
  end

  @impl Permit.Phoenix.LiveView
  def handle_unauthorized(_action, socket), do: {:cont, assign(socket, :unauthorized, true)}

  @impl Permit.Phoenix.LiveView
  def fetch_subject(_socket, session) do
    case session["token"] do
      "valid_token" -> %User{id: 1, roles: session["roles"] || []}
      _ -> nil
    end
  end

  @impl true
  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <button id="navigate_show" phx-click="navigate" phx-value-url="/books/1">show</button>
    <button id="navigate_edit" phx-click="navigate" phx-value-url="/books/1/edit">edit</button>
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
  def handle_params(_params, _url, socket) do
    {:noreply,
     assign(
       socket,
       :loaded_resource_was_visible_in_handle_params,
       Map.has_key?(socket.assigns, :loaded_resources) or
         Map.has_key?(socket.assigns, :loaded_resource)
     )}
  end

  @impl true
  def handle_call({:run, func}, _, socket), do: func.(socket)

  @impl true
  def handle_info({:run, func}, socket), do: func.(socket)

  def run(lv, func) do
    GenServer.call(lv.pid, {:run, func})
  end
end
