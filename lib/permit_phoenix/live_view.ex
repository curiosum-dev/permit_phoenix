defmodule Permit.Phoenix.LiveView do
  @moduledoc """
  Using this module, Permit authorization can be integrated with Phoenix LiveView at three key points:
  1. During mount (via the `on_mount: Permit.Phoenix.LiveView.AuthorizeHook` hook)
  2. During live navigation (via the `handle_params/3` callback)
  3. During events (via the `handle_event/3` callback)

  This way, Permit.Phoenix's load-and-authorize mechanism occurs regardless of whether the user has
  navigated to the page directly (from outside a LiveView session), or has navigated to a URL that stays
  within the same LiveView session (or the same LiveView instance), and also when an event is triggered
  (e.g. a `delete` button is clicked).

  ## Setup

  In the router, in a `live_session` that authenticates the user, add `Permit.Phoenix.LiveView.AuthorizeHook`
  after the `:ensure_authenticated` hook at `:on_mount`:

      live_session :require_authenticated_user,
        on_mount: [{MyAppWeb.UserAuth, :ensure_authenticated}, Permit.Phoenix.LiveView.AuthorizeHook] do
        live "/live_articles", ArticleLive.Index, :index
        live "/live_articles/new", ArticleLive.Index, :new
        live "/live_articles/:id/edit", ArticleLive.Index, :edit

        live "/live_articles/:id", ArticleLive.Show, :show
        live "/live_articles/:id/show/edit", ArticleLive.Show, :edit
      end

  Permit uses action modules to define action names that can be authorized. For convenience, you can
  pull the action names from your router - your `live_action` names will be used by Permit.

      defmodule MyApp.Actions do
        # Merge the actions from the router into the default grouping schema.
        use Permit.Phoenix.Actions, router: MyAppWeb.Router
      end

  Note that standard Phoenix action names like `:index`, `:show`, `:edit`, `:new`, `:delete`,
  `:update` are already included and configured to be plural or singular accordingly.
  For other action names from your router, you'll need to define their _arity_ in the action module
  using the `singular_actions/0` callback.

  Then, configure LiveViews to use the authorization mechanism. It can be put in individual modules,
  or in the `MyAppWeb` module's `live_view` function:

      defmodule MyAppWeb do
        def live_view do
          quote do
            use Permit.Phoenix.LiveView,
              authorization_module: MyApp.Authorization,
          end
        end
      end

  Options can be set as `use` keywords, or as callback implementations (which take precedence). This way, you can override them
  in individual LiveViews. Typically, at the very least, you'll want to set the `resource_module`
  to the related schema.

      defmodule MyAppWeb.ArticleLive.Index do
        use MyAppWeb, :live_view

        @impl true
        def resource_module, do: MyApp.Article
      end

  ## Navigation & mounting authorization

  Navigating to a LiveView route results in triggering the `handle_params/3` callback. This may occur
  in three scenarios:
  * navigating from outside a LiveView session (e.g. from a link in an email or a browser bookmark),
  * navigating within the same LiveView session, but a different LiveView instance,
  * navigating within the same LiveView instance.

  Permit's hook taps into the `handle_params/3` callback processing to **load and authorize**:
  * take the `live_action` from the socket, and use it to determine the action to authorize,
  * for a plural action (e.g. `:index`), authorize load all resources with Permit.Ecto based on `resource_module`
    * if Permit.Ecto is not present, use the `loader` function to load the resources,
  * for a singular action (e.g. `:edit`), load the resource with Permit.Ecto based on `resource_module` and `id_param_name`/`id_struct_field_name`
    options (defaulting to `:id` for the latter), and authorize it,
    * if Permit.Ecto is not present, use the `loader` function likewise,

  Example of a singular action:

      @impl true
      def handle_params(_params, _uri, socket) do
        # Article is loaded and authorized by Permit
        article = socket.assigns.loaded_resource

        {:noreply, socket |> assign(:title, article.title)}
      end

  If an action is defined as plural in the actions module, resources are either assigned to `:loaded_resources`
  (by default), or streamed as `:loaded_resources` if `use_stream?/1` is `true`.

      # Default: assign to `:loaded_resources`
      @impl true
      def handle_params(_params, _uri, socket) do
        # Article list is loaded
        articles =
      end

      # Optional: set `use_stream?/1` to `true` to use streams instead of assigns
      @impl true
      def use_stream?(_socket), do: true

      @impl true
      def handle_params(_params, _uri, socket) do
        # Article list available in @streams.loaded_resources
        {:noreply, socket}
      end

  ### Notes on mounting and handling authorization failure

  An important note is that, in the first two scenarios, the new LiveView has to be mounted, whereas
  in the third one, it is already mounted. It is of significance to implementing `handle_unauthorized/2`
  correctly, because if the LiveView is in the mounting phase, a redirect navigation is required, whereas
  if it is already mounted, any way of handling the event is acceptable.

  For convenience, this module provides the `mounting?/1` function, which returns `true` if the
  LiveView is in the mounting phase, and `false` otherwise. It can be used in the `handle_unauthorized/2`
  callback implementation to determine the appropriate response in a custom way.

      @impl true
      def handle_unauthorized(action, socket) do
        if mounting?(socket) do
          {:halt, push_navigate(socket, to: socket.view.fallback_path())}
        else
          # Do whatever you want with the socket here...
          socket = assign(socket, :unauthorized, true)

          # Use :cont to continue processing the module's handle_params/3 handlers,
          # or :halt to halt the processing.
          {:halt, socket |> put_flash(:error, "You are not authorized to access this page")}
        end
      end

  See documentation for `handle_unauthorized/2` for more guidance and explanation of default behaviour.

  ## Event authorization

  Actions such as updating or deleting a resource are typically implemented in LiveView using `handle_event/3`.
  Permit taps into `handle_event/3` processing, loads the resource with Permit.Ecto (or a loader function) based
  on the event's `"id"` param and a query based on the currently resolved permissions and puts it in `assigns`.
  If authorization fails, `handle_unauthorized/2` is called.

  Event to action mapping must be given in the `event_mapping/0` callback. There is no default mapping as
  event names typically suggested by Phoenix may map to different actions (e.g. Phoenix generates `"save"`
  for both `:create` and `:update` actions).

      @impl true
      # "delete" event maps to :delete Permit action
      def event_mapping, do: %{"delete" => :delete}

      @impl true
      def handle_event("delete", _params, _socket) do
        # Resource is loaded and authorized by Permit
        article = socket.assigns.loaded_resource

        # Delete the record
        {:ok, _} = MyApp.Blog.delete_article(article)

        # If in an action like :index, stream the deletion to the client.
        # Permit either streams the viewed items or assigns them (see `use_stream?/1` callback)
        {:noreply, stream_delete(socket, :loaded_resources, article)}
      end

      @impl true
      def handle_unauthorized(:delete, socket) do
        # You actually don't need to implement it, but it's useful for defining custom behaviour.
        {:halt, socket |> put_flash(:error, "You are not authorized to delete this article")}
      end

  The full list of options can be found in this module's callback specifications.
  """
  alias Permit.Phoenix.Types, as: PhoenixTypes
  alias Permit.Types
  alias Permit.Phoenix.RecordNotFoundError

  import Phoenix.LiveView

  # Check project config (works for both hex and path deps)
  @permit_ecto_available? Permit.Phoenix.Utils.permit_ecto_available?()

  @callback resource_module() :: module()

  @doc """
  Defines the action grouping schema for this live view.
  This can be overridden in individual live views to customize the action mapping.
  """
  @callback action_grouping() :: map()

  @doc """
  Defines which actions are considered singular (operating on a single resource).
  This can be overridden in individual live views to customize the singular actions.
  """
  @callback singular_actions() :: [atom()]

  if @permit_ecto_available? do
    @callback base_query(Types.resolution_context()) :: Ecto.Query.t()
    @callback finalize_query(Ecto.Query.t(), Types.resolution_context()) :: Ecto.Query.t()
  end

  @doc ~S"""
  Called when authorization fails either in `handle_event` or `handle_params` (both during
  mounting and navigation). `{:cont, ...}` or `{:halt, ...}` can be used to either continue
  executing the normal handlers or halt.

  Defaults to halting, displaying a flash and staying on the same page if possible, either
  via not navigating at all or by navigating to `_live_referer` - otherwise (e.g. when entering
  a page from outside a LiveView session) redirects to `:fallback_path`, defaulting to `/`.

  ## Example

      # Default implementation
      @impl true
      def handle_unauthorized(action, socket) do
        # navigate_if_mounting/2 calls push_navigate/2 if Permit.Phoenix.LiveView.mounting?/1 returns true
        {:halt,
         socket
         |> put_flash(:error, socket.view.unauthorized_message(action, socket))
         |> navigate_if_mounting(to: socket.view.fallback_path(action, socket))}
      end

      defp navigate_if_mounting(socket, opts) do
        if mounting?(socket), do: navigate(socket, arg), else: socket
      end
  """
  @callback handle_unauthorized(Types.action_group(), PhoenixTypes.socket()) ::
              PhoenixTypes.hook_outcome()
  @callback fetch_subject(PhoenixTypes.socket(), map()) :: Types.subject()
  @callback authorization_module() :: Types.authorization_module()
  @callback preload_actions() :: list(Types.action_group())
  @callback fallback_path(Types.action_group(), PhoenixTypes.socket()) :: binary()
  @callback except() :: list(Types.action_group())
  @callback loader(Types.resolution_context()) :: Types.object() | nil
  @callback handle_not_found(PhoenixTypes.socket()) :: PhoenixTypes.hook_outcome()
  @callback id_param_name(Types.action_group(), PhoenixTypes.socket()) :: binary()
  @callback id_struct_field_name(Types.action_group(), PhoenixTypes.socket()) :: atom()
  @callback unauthorized_message(PhoenixTypes.socket(), map()) :: binary()
  @callback event_mapping() :: map()
  @callback use_stream?(PhoenixTypes.socket()) :: boolean()
  @doc ~S"""
  Determines whether to use Phoenix Scopes for fetching the subject. Set to `false` in Phoenix <1.8.

  If `true`, the subject will be fetched from `current_scope.user`. If `false`, the subject will be fetched from `current_user` assign.

  Defaults to `true`.
  """
  @callback use_scope?() :: boolean()

  @doc ~S"""
  Maps the current Phoenix scope to the subject, if Phoenix Scopes are used (see the `use_scope?/0` callback). Defaults to `scope.user`.

  Defaults to `:user`.

  ## Example

      @impl true
      def scope_subject(scope) do
        # Use the entire scope as the subject
        scope

        # Use a specific key in the scope
        scope.user
      end
  """
  @callback scope_subject(map()) :: PhoenixTypes.scope_subject()
  @optional_callbacks [
                        if(@permit_ecto_available?,
                          do: {:base_query, 1}
                        ),
                        if(@permit_ecto_available?,
                          do: {:finalize_query, 2}
                        ),
                        handle_unauthorized: 2,
                        preload_actions: 0,
                        fallback_path: 2,
                        resource_module: 0,
                        except: 0,
                        fetch_subject: 2,
                        loader: 1,
                        id_param_name: 2,
                        id_struct_field_name: 2,
                        handle_not_found: 1,
                        unauthorized_message: 2,
                        use_stream?: 1,
                        use_scope?: 0,
                        scope_subject: 1
                      ]
                      |> Enum.filter(& &1)

  defmacro __using__(opts) do
    quote generated: true do
      import unquote(__MODULE__)

      if unquote(@permit_ecto_available?) do
        require Ecto.Query
      end

      @behaviour unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      @opts unquote(opts)

      @impl true
      def event_mapping, do: unquote(__MODULE__).event_mapping()

      @impl true
      def handle_unauthorized(action, socket) do
        unquote(__MODULE__).handle_unauthorized(action, socket, unquote(opts))
      end

      @impl true
      def unauthorized_message(action, socket) do
        unquote(__MODULE__).unauthorized_message(action, socket, unquote(opts))
      end

      @impl true
      def authorization_module,
        do:
          unquote(opts[:authorization_module]) ||
            raise(":authorization_module option must be given when using LiveViewAuthorization")

      @impl true
      def handle_not_found(socket) do
        unquote(__MODULE__).handle_not_found(socket, unquote(opts))
      end

      @impl true
      def resource_module, do: unquote(opts[:resource_module])

      @impl true
      def preload_actions,
        do: (unquote(opts[:preload_actions]) || []) ++ [:show, :edit, :index, :delete]

      @impl true
      def fallback_path(action, socket) do
        unquote(__MODULE__).fallback_path(action, socket, unquote(opts))
      end

      @impl true
      def except, do: unquote(opts[:except]) || []

      if unquote(@permit_ecto_available?) do
        @impl true
        def base_query(%{
              action: action,
              resource_module: resource_module,
              socket: socket,
              params: params
            }) do
          param = id_param_name(action, socket)
          field = id_struct_field_name(action, socket)

          case params do
            %{^param => id} ->
              resource_module
              |> Permit.Ecto.filter_by_field(field, id)

            _ ->
              Permit.Ecto.from(resource_module)
          end
        end

        @impl true
        def finalize_query(query, resolution_context),
          do: unquote(__MODULE__).finalize_query(query, resolution_context, unquote(opts))
      end

      @impl true
      def id_param_name(action, socket) do
        unquote(__MODULE__).id_param_name(action, socket, unquote(opts))
      end

      @impl true
      def id_struct_field_name(action, socket) do
        unquote(__MODULE__).id_struct_field_name(action, socket, unquote(opts))
      end

      @impl true
      def use_stream?(socket) do
        case unquote(opts[:use_stream?]) do
          fun when is_function(fun) -> fun.(socket) || false
          other -> other || false
        end
      end

      @impl true
      def use_scope? do
        case unquote(opts[:use_scope?]) do
          fun when is_function(fun) -> fun.()
          nil -> true
          other -> other
        end
      end

      @impl true
      def scope_subject(scope) when is_map(scope) do
        case unquote(opts[:scope_subject]) do
          fun when is_function(fun) -> fun.(scope)
          nil -> scope.user
          key -> scope |> Map.fetch!(key)
        end
      end

      # Default implementations
      @impl true
      def action_grouping do
        Permit.Phoenix.Actions.grouping_schema()
      end

      @impl true
      def singular_actions do
        unquote(opts)[:authorization_module].permissions_module().actions_module().singular_actions()
      end

      defoverridable(
        [
          if(unquote(@permit_ecto_available?),
            do: {:base_query, 1}
          ),
          if(unquote(@permit_ecto_available?),
            do: {:finalize_query, 2}
          ),
          handle_unauthorized: 2,
          preload_actions: 0,
          fallback_path: 2,
          resource_module: 0,
          except: 0,
          id_param_name: 2,
          id_struct_field_name: 2,
          handle_not_found: 1,
          unauthorized_message: 2,
          action_grouping: 0,
          singular_actions: 0,
          use_stream?: 1,
          event_mapping: 0,
          use_scope?: 0,
          scope_subject: 1
        ]
        |> Enum.filter(& &1)
      )
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      if Module.defines?(__MODULE__, {:loader, 1}) do
        def use_loader?, do: true
      else
        def use_loader?, do: false
        @impl true
        def loader(resolution_context) do
          unquote(__MODULE__).loader(resolution_context, @opts)
        end
      end
    end
  end

  @doc """
  Returns true if inside mount/1, false otherwise. Useful for distinguishing between
  rendering directly via router or being in a handle_params lifecycle.

  For example, a handle_unauthorized/1 implementation must redirect when halting during mounting,
  while it needn't redirect when halting during the handle_params lifecycle.

  ## Example

      @impl true
      def handle_unauthorized(socket) do
        if mounting?(socket) do
          {:halt, push_redirect(socket, to: "/foo")}
        else
          {:halt, assign(socket, :unauthorized, true)}
        end
      end
  """
  @spec mounting?(PhoenixTypes.socket()) :: boolean()
  def mounting?(socket) do
    Phoenix.LiveView.get_connect_info(socket, :uri)
    true
  rescue
    # Raises RuntimeError if outside mount/1 because socket_info only exists while mounting.
    # This allows us to distinguish between accessing directly from router or via e.g. handle_params.
    RuntimeError -> false
  end

  @doc false
  def event_mapping do
    %{
      "create" => :create,
      "delete" => :delete,
      "edit" => :edit,
      "index" => :index,
      "new" => :new,
      "show" => :show,
      "update" => :update
    }
  end

  @doc false
  def handle_unauthorized(action, socket, opts) do
    case opts[:handle_unauthorized] do
      nil ->
        {:halt,
         socket
         |> put_flash(:error, socket.view.unauthorized_message(action, socket))
         |> navigate_if_mounting(to: socket.view.fallback_path(action, socket))}

      fun when is_function(fun) ->
        fun.(action, socket)

      handle_unauthorized ->
        handle_unauthorized
    end
  end

  def unauthorized_message(action, socket, opts) do
    case opts[:unauthorized_message] do
      nil -> "You do not have permission to perform this action."
      fun when is_function(fun) -> fun.(action, socket)
      msg -> msg
    end
  end

  def handle_not_found(_socket, _opts) do
    raise RecordNotFoundError, "Expected at least one result but got none"
  end

  @doc false
  def fallback_path(action, socket, opts) do
    case opts[:fallback_path] do
      nil ->
        try do
          referer_url = get_connect_params(socket)["_live_referer"]

          if referer_url,
            do:
              URI.parse(referer_url)
              |> then(fn
                %{path: path, query: nil} -> path
                %{path: path, query: query} -> "#{path}?#{query}"
              end),
            else: "/"
        rescue
          RuntimeError -> "/"
        end

      fun when is_function(fun) ->
        fun.(action, socket)

      path ->
        path
    end
  end

  if @permit_ecto_available? do
    @doc false

    def base_query(
          %{
            action: action,
            resource_module: resource_module,
            socket: socket,
            params: params
          },
          opts
        ) do
      param = __MODULE__.id_param_name(action, socket, opts)
      field = __MODULE__.id_struct_field_name(action, socket, opts)

      # since Permit.Ecto may not be loaded, we use apply/3 to call the function
      # to suppress warnings
      case params do
        %{^param => id} ->
          apply(Permit.Ecto, :filter_by_field, [resource_module, field, id])

        _ ->
          apply(Permit.Ecto, :from, [resource_module])
      end
    end

    @doc false
    def finalize_query(query, %{}, _opts), do: query
  end

  @doc false
  def loader(resolution_context, opts) do
    case opts[:loader] do
      nil -> nil
      function -> function.(resolution_context)
    end
  end

  @doc false
  def id_param_name(action, socket, opts) do
    case opts[:id_param_name] do
      nil -> "id"
      param_name when is_binary(param_name) -> param_name
      param_name_fn when is_function(param_name_fn) -> param_name_fn.(action, socket)
    end
  end

  @doc false
  def id_struct_field_name(action, socket, opts) do
    case opts[:id_struct_field_name] do
      nil ->
        :id

      struct_field_name when is_binary(struct_field_name) ->
        struct_field_name

      struct_field_name_fn when is_function(struct_field_name_fn) ->
        struct_field_name_fn.(action, socket)
    end
  end

  defp navigate_if_mounting(socket, arg) do
    if mounting?(socket), do: navigate(socket, arg), else: socket
  end

  defp navigate(socket, arg) do
    if function_exported?(Phoenix.LiveView, :push_navigate, 2) do
      apply(Phoenix.LiveView, :push_navigate, [socket, arg])
    else
      apply(Phoenix.LiveView, :push_redirect, [socket, arg])
    end
  end
end
