defmodule Permit.EctoLiveViewTest.HooksWithCustomOptsLive do
  use Phoenix.LiveView, namespace: Permit

  alias Permit.EctoFakeApp.{Authorization, Item, User}
  alias Permit.EctoFakeApp.Item.Context

  use Permit.Phoenix.LiveView,
    authorization_module: Authorization,
    resource_module: Item

  @impl true
  def fallback_path(_action, _socket) do
    "/live/?foo"
  end

  @impl true
  def unauthorized_message(_action, _socket) do
    "Lorem ipsum."
  end

  @impl Permit.Phoenix.LiveView
  def base_query(%{resource_module: Item, params: params}) do
    case params do
      %{"id" => id} ->
        id =
          if is_bitstring(id) do
            String.to_integer(id)
          else
            id
          end

        Context.filter_by_id(Item, id)

      %{} ->
        Item
    end
  end

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
    Rendered!
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, mounted: true)}
  end

  @impl true
  def handle_call({:run, func}, _, socket), do: func.(socket)

  @impl true
  def handle_info({:run, func}, socket), do: func.(socket)

  def run(lv, func) do
    GenServer.call(lv.pid, {:run, func})
  end
end
