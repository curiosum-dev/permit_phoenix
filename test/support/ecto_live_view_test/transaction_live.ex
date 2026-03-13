defmodule Permit.EctoLiveViewTest.TransactionLive do
  @moduledoc """
  LiveView for testing authorize_with_transaction in handle_event.
  """
  use Phoenix.LiveView, namespace: Permit

  alias Permit.EctoFakeApp.{Authorization, Item, Repo}

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
      <button id="save" phx-click="save">Save</button>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, mounted: true)}
  end

  @impl true
  @permit_action :create
  def handle_event("save", params, socket) do
    item_params = params["item"] || %{}

    # When _authorize_as is given, override the action explicitly.
    # Otherwise, omit :action to test the default (live_action) path.
    auth_opts =
      case params["_authorize_as"] do
        nil -> []
        action_str -> [action: String.to_existing_atom(action_str)]
      end

    auth_opts =
      if params["_custom_unauthorized"] do
        Keyword.put(auth_opts, :on_unauthorized, fn _action, socket ->
          assign(socket, :custom_unauthorized, true)
        end)
      else
        auth_opts
      end

    # Allow tests to override the subject via _subject_id param.
    # Constructs a User with the :creator role so SubjectMapping resolves properly.
    auth_opts =
      if subject_id = params["_subject_id"] do
        Keyword.put(auth_opts, :subject, %Permit.EctoFakeApp.User{
          id: String.to_integer(subject_id),
          roles: [:creator]
        })
      else
        auth_opts
      end

    case authorize_with_transaction(
           socket,
           fn -> Repo.insert(Item.changeset(%Item{}, item_params)) end,
           auth_opts
         ) do
      {:ok, item} ->
        {:noreply, assign(socket, :created_item, item)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset_error, changeset)}

      {:error, socket} ->
        {:noreply, socket}
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

  def run(liveview, func) do
    GenServer.call(liveview.pid, {:run, func})
  end
end
