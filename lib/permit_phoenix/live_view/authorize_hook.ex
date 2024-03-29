defmodule Permit.Phoenix.LiveView.AuthorizeHook do
  @moduledoc """
  Hooks into the :mount and :handle_params lifecycles to authorize the current action.
  The current action is denoted by the :live_action assign (retrieved from the router),
  for example with the following route definition:

      live "/organizations", OrganizationLive.Index, :index

  the :live_action assign value will be :index.

  ## Configuration

  In the router, use the :on_mount option of live_session to configure it, passing a tuple.
  For convenience, you might return this tuple from a function that you might import into the router.

    live_session :some_session, on_mount: Permit.Phoenix.LiveView.AuthorizeHook do
      live "/organizations", MyLive.Index, :index
      # ...
    end

  ## Usage

  Authorization is done on live view mount and in handle_params (where the URL, and
  hence assigns.live_action, may change).

  A live view module using the authorization mechanism should mix in the LiveViewAuthorization
  module:

      defmodule MyAppWeb.DocumentLive.Index
        use Permit.Phoenix.LiveView
      end

  which adds the LiveViewAuthorization behavior with the following callbacks to be implemented -
  for example:

      # The related schema
      def resource_module, do: Document

      # Loader function for a singular resource in appropriate actions (:show, etc.); usually a context
      # function. If not defined, Repo.get is used by default.
      def loader, do: fn id -> get_organization!(id) end

  Depending on whether you use `use MyAppWeb, :live_view` or not to configure your LiveViews,
  it might be more convenient to provide configuration as options when you mix it in via `use`.
  For instance:

      # my_app_web.ex
      def live_view do
        use Permit.Phoenix.LiveView,
          authorization_module: Lvauth.Authorization,
          fallback_path: "/unauthorized"
      end

      # your live view module
      defmodule MyAppWeb.PageLive do
        use MyAppWeb, :live_view

        @impl true
        def resource_module, do: MyApp.Item

        # you might or might not want to override something here
        @impl true
        def fallback_path: "/foo"
      end

  In actions like :show, where a singular resource is to be authorized and preloaded, it is preloaded into
  the :loaded_resources assign. This way, you can implement your :handle_params event without caring
  about loading the record:

      @impl true
      def handle_params(_params, _, socket) do
        {:noreply,
        socket
        |> assign(:page_title, page_title(socket.assigns.live_action))
        |> assign(:organization, socket.assigns.loaded_resources)}
      end

  Optionally, a handle_unauthorized/2 optional callback can be implemented, returning {:cont, socket}
  or {:halt, socket}. The default implementation returns:

      {:halt, push_redirect(socket, to: socket.view.fallback_path())}

  """

  alias Permit.Phoenix.Types, as: PhoenixTypes

  # These two modules will be checked for the existence of the assign/3 function.
  # If neither exists (no LiveView dependency in a project), no failure happens.
  Code.ensure_loaded(Phoenix.LiveView)
  Code.ensure_loaded(Phoenix.Component)

  defmacro live_view_assign(socket_or_assigns, key, value) do
    cond do
      Kernel.function_exported?(Phoenix.LiveView, :assign, 3) ->
        quote do
          Phoenix.LiveView.assign(unquote(socket_or_assigns), unquote(key), unquote(value))
        end

      Kernel.function_exported?(Phoenix.Component, :assign, 3) ->
        quote do
          Phoenix.Component.assign(unquote(socket_or_assigns), unquote(key), unquote(value))
        end

      true ->
        quote do
          raise RuntimeError,
                """
                Phoenix LiveView is not available.
                Please add a dependency {:phoenix_live_view, \"~> 0.16\"} to use LiveView integration.
                """
        end
    end
  end

  @spec on_mount(term(), map(), map(), PhoenixTypes.socket()) :: PhoenixTypes.hook_outcome()
  def on_mount(_opt, params, session, socket) do
    socket
    |> attach_params_hook(params, session)
    |> authenticate_and_authorize!(session, params)
  end

  defp authenticate_and_authorize!(socket, session, params) do
    socket
    |> authenticate(session)
    |> authorize(params)
    |> respond()
  end

  @spec authenticate(PhoenixTypes.socket(), map()) :: PhoenixTypes.socket()
  defp authenticate(socket, session) do
    current_user = socket.view.fetch_subject(socket, session)
    live_view_assign(socket, :current_user, current_user)
  end

  @spec authorize(PhoenixTypes.socket(), map()) :: PhoenixTypes.live_authorization_result()
  defp authorize(socket, params) do
    %{assigns: %{live_action: live_action}} = socket

    if live_action in socket.view.preload_actions() do
      preload_and_authorize(socket, params)
    else
      just_authorize(socket)
    end
  end

  @spec just_authorize(PhoenixTypes.socket()) :: PhoenixTypes.live_authorization_result()
  defp just_authorize(socket) do
    authorization_module = socket.view.authorization_module()
    resource_module = socket.view.resource_module()
    resolver_module = authorization_module.resolver_module()
    subject = socket.assigns.current_user
    action = socket.assigns.live_action

    case resolver_module.authorized?(
           subject,
           authorization_module,
           resource_module,
           action
         ) do
      true -> {:authorized, socket}
      false -> {:unauthorized, socket}
    end
  end

  @spec preload_and_authorize(PhoenixTypes.socket(), map()) ::
          PhoenixTypes.live_authorization_result()
  defp preload_and_authorize(socket, params) do
    use_loader? = socket.view.use_loader?()
    authorization_module = socket.view.authorization_module()
    actions_module = authorization_module.actions_module()
    resolver_module = authorization_module.resolver_module()
    resource_module = socket.view.resource_module()

    base_query = &socket.view.base_query/1
    loader = &socket.view.loader/1
    finalize_query = &socket.view.finalize_query/2
    subject = socket.assigns.current_user
    action = socket.assigns.live_action
    singular? = action in actions_module.singular_actions()

    {load_key, other_key, auth_function} =
      if singular? do
        {:loaded_resource, :loaded_resources, &resolver_module.authorize_and_preload_one!/5}
      else
        {:loaded_resources, :loaded_resource, &resolver_module.authorize_and_preload_all!/5}
      end

    case auth_function.(
           subject,
           authorization_module,
           resource_module,
           action,
           %{
             params: params,
             loader: loader,
             socket: socket,
             base_query: base_query,
             finalize_query: finalize_query,
             use_loader?: use_loader?
           }
         ) do
      {:authorized, records} ->
        {:authorized,
         socket
         |> live_view_assign(load_key, records)
         |> live_view_assign(other_key, nil)}

      :unauthorized ->
        {:unauthorized,
         socket
         |> live_view_assign(load_key, nil)
         |> live_view_assign(other_key, nil)}

      :not_found ->
        {:not_found,
         socket
         |> live_view_assign(load_key, nil)
         |> live_view_assign(other_key, nil)}
    end
  end

  @spec respond(PhoenixTypes.live_authorization_result()) :: PhoenixTypes.hook_outcome()
  defp respond(live_authorization_result)

  defp respond({:unauthorized, socket}) do
    socket.view.handle_unauthorized(socket.assigns[:live_action], socket)
  end

  defp respond({:not_found, socket}) do
    socket.view.handle_not_found(socket)
  end

  defp respond({:authorized, socket}) do
    {:cont, socket}
  end

  defp attach_params_hook(socket, _mount_params, session) do
    socket
    |> Phoenix.LiveView.attach_hook(:params_authorization, :handle_params, fn params,
                                                                              _uri,
                                                                              socket ->
      authenticate_and_authorize!(socket, session, params)
    end)
  end
end
