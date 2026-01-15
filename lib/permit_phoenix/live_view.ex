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

  ## Schematic overview

  The diagram below illustrates the flow of authorization in Permit.Phoenix LiveView in the context of
  what happens when a user navigates to a LiveView route.

  ```mermaid
  flowchart TD
    Start([USER NAVIGATES])
    Start --> Outside["From Outside
    (browser link, bookmark)"]
    Start --> SameSession["Same LiveView Session
    (diff instance)"]
    Start --> SameInstance["Same LiveView Instance
    (patch nav)"]

    Outside --> Mount["MOUNT PHASE
    New LiveView mounts, AuthorizeHook module
    attaches hooks to params and event handlers
    and loads & authorizes based on @live_action,
    then assigns to @loaded_resource(s)"]
    SameSession --> Mount

    SameInstance --> HandleParams["HANDLE_PARAMS/3
    Load & authorize based on @live_action
    Assign @loaded_resource(s)"]
    Mount --> HandleParams

    HandleParams --> Running["LiveView instance running"]
    Running -.-> HandleEvent["HANDLE_EVENT/3
    Authorize events via @permit_action
    or event_mapping/0"]

    Running -.-> HandleParams
    HandleEvent -.-> Running
  ```

  ## Setup

  In the router, in a `live_session` that authenticates the user, add `Permit.Phoenix.LiveView.AuthorizeHook`
  after the `:ensure_authenticated` hook at `:on_mount`:

      live_session :require_authenticated_user,
        on_mount: [
          {MyAppWeb.UserAuth, :ensure_authenticated},
          Permit.Phoenix.LiveView.AuthorizeHook         # add Permit.Phoenix's hook at mount
        ] do
        live "/live_articles", ArticleLive.Index, :index
        live "/live_articles/new", ArticleLive.Index, :new
        live "/live_articles/:id/edit", ArticleLive.Index, :edit

        live "/live_articles/:id", ArticleLive.Show, :show
        live "/live_articles/:id/show/edit", ArticleLive.Show, :edit
      end

  Names of `:live_action`'s defined in the router are important - they are directly mapped to Permit action names.
  If an action name is defined in your app's actions module (see `Permit.Phoenix.Actions`), or in the router, it will
  be generated as a convenience function in your permissions module.

  ```
  # Your router

  defmodule MyAppWeb.Router do
    use Phoenix.Router
    import Phoenix.LiveView.Router

    live_session :require_authenticated_user, on_mount: [
      {MyAppWeb.UserAuth, :ensure_authenticated},
      Permit.Phoenix.LiveView.AuthorizeHook
    ] do
      # Define routes with :live_action named :view and :all
      live("/articles/:id/view", MyAppWeb.ArticleLive, :view)
      live("/articles/:id/all", MyAppWeb.ArticleLive, :all)
    end
  end

  # Your actions module
  defmodule MyApp.Actions do
    use Permit.Phoenix.Actions, router: MyAppWeb.Router

    # Permit.Phoenix.Actions includes :index, :show, :update, :edit, :create, :new, :delete
    # Specifying the router will include action names from the router

    # Clarify that the :view action relates to a single resource, not a listing.
    # :all will be a plural action, loading all articles for the current user.
    @impl true
    def singular_actions do
      [:view]
    end
  end

  # Your permissions module
  defmodule MyApp.Permissions do
    use Permit.Ecto.Permissions, actions_module: MyApp.Actions

    # The :view and :all actions generate `view/2` and `all/2` functions, so we can use them here
    def can(:show = _action) do
      permit()
      |> view(MyApp.Article)
      |> all(MyApp.Article)
    end
  end
  ```

  Then, configure LiveViews to use the authorization mechanism. It can be put in individual modules,
  or in the `MyAppWeb` module's `live_view` function:

      defmodule MyAppWeb do
        def live_view do
          quote do
            use Permit.Phoenix.LiveView,
              authorization_module: MyApp.Authorization,
              # other options...
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

  ### Authorization flow

  The `Permit.Phoenix.LiveView.AuthorizeHook` module taps into the `handle_params/3` callback processing.
  When it is triggered on navigation to a LiveView route, the route's `:live_action`
  is used to determine the action to authorize. Records are filtered and loaded is loaded using
  Permit.Ecto based on the `resource_module` and `id_param_name`/`id_struct_field_name` options,
  the `base_query`, and resolved authorization conditions (or with a loader function when Permit.Ecto
  is not used).

  ```mermaid
  flowchart TD
    Start["HANDLE_PARAMS/3 TRIGGERED"]

    Hook["Hook attached by Permit.Phoenix
    ─────────────────────────────────────
    1. Get @live_action from socket
    2. Check if in except/0 (skip?)
    3. Determine singular vs plural"]

    ActionAuth["ACTION AUTHORIZATION
    ─────────────────────────────────────
    Fails if there is no permission to @live_action
    altogether: user |> can(:read, Article, ...)"]

    Singular["SINGULAR ACTION
    (:show, :edit, etc)
    ──────────────────────
    Load single record via id_param_name
    (id by default)"]

    Plural["PLURAL ACTION
    (:index, etc.)
    ──────────────────────
    Load all records filtered
    by user's permissions"]

    Start --> Hook
    Hook --> ActionAuth
    ActionAuth --> Singular
    ActionAuth --> Plural
    Singular --> Note1
    Plural --> Note1
    Note1[Record loading done using Permit.Ecto automatically generates query based on<br/>permissions and params. Alternatively, loader/1 callback loads records if Permit.Ecto not used.]
  ```

  Now that the record (or list of records) is loaded, authorization is finally verified against resolved
  permissions. If it succeeds, a single record is assigned to `:loaded_resource`, or a list is assigned
  or streamed to `:loaded_resources`, and execution continues in the `handle_params/3` callback
  implementation.
  Otherwise, depending on what kind of error happened, `c:handle_unauthorized/2` or `c:handle_not_found/1`
  is called. These callbacks may either halt (default), or continue so that we can still go back to
  `handle_params/3`, which is possible but discouraged.

  ```mermaid
  flowchart TD
    AuthCheck["AUTHORIZATION CHECK"]

    Authorized["AUTHORIZED
    ──────────────────────
    {:cont, socket}
    with resource(s) assigned or streamed"]

    Unauthorized["UNAUTHORIZED
    ──────────────────────
    handle_unauthorized/2

    Default: flash + stay on page
    if possible, or redirect to
    fallback path"]

    NotFound["NOT FOUND
    ──────────────────────
    handle_not_found/1

    Default: raise error"]

    UserImplementation["YOUR handle_params/3 IMPLEMENTATION
    (receives socket with resources)"]

    AuthCheck --> Authorized
    AuthCheck --> Unauthorized
    AuthCheck --> NotFound
    Authorized --> UserImplementation
    Unauthorized --> UserImplementation
    NotFound --> UserImplementation

    linkStyle 4,5 stroke-dasharray: 5 5
  ```

  Example of usage with a singular action:

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
        # Article list is loaded to @loaded_resources
        {:noreply, socket}
      end

      # Optional: set `use_stream?/1` to `true` to use streams instead of assigns
      @impl true
      def use_stream?(_socket), do: true

      @impl true
      def handle_params(_params, _uri, socket) do
        # Article list available in @streams.loaded_resources
        {:noreply, socket}
      end

  ## Event authorization

  Actions such as updating or deleting a resource are typically implemented in LiveView using `handle_event/3`.
  Permit taps into `handle_event/3` processing and, depending on the event's nature:
  * For events carrying an `"id"` param (e.g. record deletion from an index page), **loads the record** with
    Permit.Ecto (or a loader function) based on the ID param and a query based on the currently resolved
    permissions and puts it in `assigns`.
  * For events that do not carry an `"id"` param (e.g. updating a record with form data), **reloads the
    record** currently assigned to `@loaded_resource`, using either Permit.Ecto (and the record's ID) or
    the existing loader function. This is done by default to ensure permissions are evaluated against the
    latest data. You can disable this behaviour by overriding `reload_on_event?/2` (or by passing the
    `:reload_on_event?` option) if you prefer to reuse the already assigned record.


  ```mermaid
  flowchart TD
    Start["USER TRIGGERS EVENT (e.g. click)"]

    Hook["Hook attached by Permit.Phoenix
    ─────────────────────────────────────
    1. Map event → action via:
       • @permit_action attributes
       • event_mapping/0 callback
       • default_event_mapping/0"]

    WithId["EVENT HAS 'id' PARAM
    (e.g. delete from index page)
    ──────────────────────
    Load record by ID from params"]

    NoId["NO 'id' PARAM
    (e.g. form submit)
    ──────────────────────
    RELOAD existing @loaded_resource
    (if reload_on_event? is true)"]

    AuthCheck["AUTHORIZATION CHECK"]

    Authorized["AUTHORIZED
    ──────────────────────
    Assign to: @loaded_resource"]

    Unauthorized["UNAUTHORIZED
    ──────────────────────
    handle_unauthorized/2

    Default: flash + stay on page
    or fallback_path"]

    NotFound["NOT FOUND
    ──────────────────────
    handle_not_found/1

    Default: raise error"]

    UserImplementation["YOUR handle_event/3 IMPLEMENTATION
    (@loaded_resource available)"]

    Start --> Hook
    Hook --> WithId
    Hook --> NoId
    WithId --> Note1
    NoId --> Note1
    Note1[Record loading done using Permit.Ecto automatically generates query based on<br/>permissions and params. Alternatively, loader/1 callback loads records if Permit.Ecto not used.]
    Note1 --> AuthCheck
    AuthCheck --> Authorized
    AuthCheck --> Unauthorized
    AuthCheck --> NotFound
    Authorized --> UserImplementation
    Unauthorized --> UserImplementation
    NotFound --> UserImplementation

    linkStyle 10,11 stroke-dasharray: 5 5
  ```

  ### Usage

  Event to action mapping is given using the `@permit_action` module attribute put right before an event
  handler.

      @impl true
      @permit_action :update
      def handle_event("save", %{"article" => article_params}, socket) do
        article = socket.assigns.loaded_resource

        case MyApp.update_article(article_params) do
          # ...
        end
      end

  In this example, the `"save"` event handler is authorized against the `:update` action on `MyApp.Article`.

  Default event mapping (`Permit.Phoenix.LiveView.default_event_mapping/0`) maps most common event
  names (strings) to action names (atoms) **except for the `"save"` event. Phoenix generates `"save"`
  event handler for both `:create` and `:update` actions, hence it must be explicitly provided in code.

  When the `handle_event/3` function is not implemented using pattern matching on the first argument,
  the `event_mapping` callback must be used instead.

      @impl true
      # "delete" event maps to :delete Permit action
      def event_mapping, do: %{"delete" => :delete, "remove" => :delete}

      @impl true
      def handle_event(event_name, _params, _socket) when event_name in ["delete", "remove"] do
        # Resource is loaded and authorized by Permit
        article = socket.assigns.loaded_resource

        # Delete the record
        {:ok, _} = MyApp.Blog.delete_article(article)

        # If in an action like :index, stream the deletion to the client.
        # Permit either streams the viewed items or assigns them (see `use_stream?/1` callback)
        {:noreply, stream_delete(socket, :loaded_resources, article)}
      end

  If authorization fails, `handle_unauthorized/2` is called. Handling authorization failure is as simple as:

      @impl true
      def handle_unauthorized(:delete, socket) do
        # You actually don't need to implement it, but it's useful for defining custom behaviour.
        {:halt, socket |> put_flash(:error, "You are not authorized to delete this article")}
      end

  The full list of options can be found in this module's callback specifications.

  ## Handling failures

  Permit allows customizing the way authorization failures and record-not-found errors are handled,
  providing sane defaults for both scenarios.

  ### Authorization failure

  The `c:handle_unauthorized/2` callback is provided to enable authorization failure handling customization.
  It is used both in navigation and event authorization. It should return either `{:halt, socket}` or
  `{:cont, socket}` depending on desired behaviour.

  When navigating to a different LiveView instance, or from outside a LiveView session, the new LiveView
  has to be mounted. In this case, a `:halt` and a redirect is required. If it's a navigation within the same
  LiveView instance, or when it occurs in event authorization, you can use either `:halt` or `:cont` and remain
  on the page, displaying an error or performing any appropriate action.

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

  By default, the `c:handle_unauthorized/2` callback is implemented to do one of the following, whichever
  is first possible:
  - remain on the same page and display a flash error message,
  - halt the processing and redirect to the `:fallback_path` (with a flash error), defaulting to `/`.

  ### Record not found

  The `c:handle_not_found/1` callback is provided to enable record-not-found error handling customization.

  When using Permit.Ecto to load authorized records, a query is constructed based on defined permissions
   - e.g. if the permission is `view(Article, author_id: user_id, published: true)`, the query will be constructed as
  `SELECT * FROM articles WHERE author_id = $1 AND published = TRUE AND id = $2`, containing both record
  ID and authorization conditions. If a matching record is found, it's assigned and available to the handler;
  otherwise, it can mean either of the two:
  - the record with given ID exists, but authorization conditions are not met,
  - the record does not exist at all.
  To distinguish between these two cases, Permit.Ecto will execute a second query with only the record ID
  and whatever is defined in `c:base_query/1` callback. If no matching record is found, it will call the
  `c:handle_not_found/1` callback. Otherwise, the `c:handle_unauthorized/2` callback is called.

  By default, the `c:handle_not_found/1` callback is implemented to raise a `Permit.Phoenix.RecordNotFoundError`.

  See documentation for `c:handle_unauthorized/2` and `c:handle_not_found/1` for more guidance and
  explanation of default behaviour.
  """
  alias Permit.Phoenix.Types, as: PhoenixTypes
  alias Permit.Types
  alias Permit.Phoenix.RecordNotFoundError

  import Phoenix.LiveView

  # Check project config (works for both hex and path deps)
  @permit_ecto_available? Permit.Phoenix.Utils.permit_ecto_available?()

  @doc ~S"""
  Sets the resource module (typically an Ecto schema) associated with this live view.

  In Phoenix LiveView's default convention, in modules grouped under `ArticleLive` this would
  be `Article`. Permit then uses it in the following way:

  * Load a singular resource by ID
    - When navigating to a path like `/articles/:id`, it will use Permit.Ecto (or function configured
    as `:loader`) to load the article with the given ID, and check it against authorization conditions -
    then either assign it to `@loaded_resource` possibly falling back to executing `handle_unauthorized/2`
    or `handle_not_found/1`.
    - When executing an event like `"delete"` mapped to a Permit action like `:delete` (see `c:event_mapping/0`),
    carrying the item ID, it will act likewise.
  * Reload a singular resource
    - When executing an event like `"save"` mapped to a Permit action like `:update` (see `c:event_mapping/0`),
    which carries form data and not the item ID, it will reload the item currently assigned to `@loaded_resource`
    unless `:reload_on_event?` is explicitly set to `false` (see `c:reload_on_event?/2`), and then act just as
    previously described.
  * Load a list of resources
    - When navigating to a path like `/articles`, it will build a query with Permit.Ecto based on authorization
    conditions to filter the articles by the current user's
    permissions (or load them with function configured as `:loader`), and assign them to the `:loaded_resources`
    assign or stream them to the client (depending on the `:use_stream?` option). If subject has no permission
    to the action whatsoever, `handle_unauthorized/2` is called.

  ## Example

      # Recommended: When the web module includes `use Permit.Phoenix.LiveView`:
      defmodule MyApp.ArticleLive.Show do
        use MyAppWeb, :live_view

        @impl true
        def resource_module, do: MyApp.Article
      end

      # When doing `use Permit.Phoenix.LiveView` in a specific live view:
      defmodule MyApp.ArticleLive.Show do
        use MyAppWeb, :live_view

        use Permit.Phoenix.LiveView,
          authorization_module: MyApp.Authorization,
          resource_module: MyApp.Article

        # ...
      end
  """
  @callback resource_module() :: Types.resource_module()

  @doc ~S"""
  Used to define action grouping for this live view, overriding the schema from your
  actions module (configured via `authorization_module`).

  This is the mechanism that allows you to e.g. declare that the `:update` permission
  allows both the `:edit` and `:update` actions to be performed.

  See `Permit.Phoenix.Actions` for reference on semantics.
  """
  @callback action_grouping() :: map()

  @doc ~S"""
  Used to define which actions are considered singular (operating on a single resource),
  overriding the schema from your actions module (configured via `authorization_module`).

  For example, a `:view` action taking a record ID from path parameters should be configured
  as singular, whereas a `:list` action that doesn't take an ID and fetches a list of records
  is plural.

  See `Permit.Phoenix.Actions` for reference.
  """
  @callback singular_actions() :: [atom()]

  if @permit_ecto_available? do
    @doc ~S"""
    Creates the basis for an Ecto query constructed by `Permit.Ecto` based on live view action,
    resource module, subject (taken from `current_scope.user` unless configured otherwise)
    and route parameters.

    It's recommended to call `super(arg)` in your implementation to ensure proper
    base query handling for both singular actions (like :show, which need ID filtering)
    and plural actions (like :index, which may handle delete events).

    ## Example

        defmodule MyApp.CommentLive.Show do
          use MyAppWeb, :live_view

          # A route like `/articles/:article_id/comments/:id`
          @impl true
          def base_query(%{action: :show, params: %{"article_id" => article_id}} = context) do
            # Original base query is automatically constructed by Permit.Ecto
            # based on `:id`. We need to filter by `article_id` as well because of the route.

            super(context)
            |> MyApp.CommentQueries.by_article_id(article_id)
          end
        end
    """
    @callback base_query(Types.resolution_context()) :: Ecto.Query.t()

    @doc ~S"""
    Post-processes an Ecto query constructed by `Permit.Ecto`. Usually, `c:base_query/1` should
    be used; the only case when `c:finalize_query/2` should be used is when you need to modify the query
    based on conditions derived from the generated query structure.

    ## Example

        defmodule MyApp.CommentLive.Show do
          use MyAppWeb, :live_view

          @impl true
          def finalize_query(generated_query, %{action: :show, params: %{"article_id" => article_id}} = resolution_context) do
            # Post-process the query and return a new one
          end
        end
    """
    @callback finalize_query(Ecto.Query.t(), Types.resolution_context()) :: Ecto.Query.t()
  end

  @doc ~S"""
  Called when authorization fails either in `handle_event` or `handle_params` (both during
  mounting and navigation). `{:cont, ...}` or `{:halt, ...}` can be used to either continue
  executing the normal handlers or halt.

  Defaults to halting, displaying a flash and staying on the same page if possible, either
  via not navigating at all or by navigating to `_live_referer` - otherwise (e.g. when entering
  a page from outside a LiveView session) redirects to `:fallback_path`, defaulting to `/`.

  When using Permit.Ecto with actions that load a single resource (e.g. `:show`), a query is
  constructed based on the record ID, `c:base_query/1`, and authorization conditions.
  If no matching record is found, a second query (without the authorization conditions) is
  executed to distinguish between authorization failure and record not existing in the database.
  If the second query returns a result, `c:handle_not_found/1` is called instead; otherwise,
  this callback is used.

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

  @doc ~S"""
  Allows overriding the subject (current user) retrieval logic.

  When implemented, Permit executes this callback at the load-and-authorize stage instead of
  using `@current_scope.user` or `@current_user`. The result of this callback is used as the
  subject, and the `:use_scope?` option is ignored.

  The fetched subject is **not** cached in anyway or assigned to the socket.

  ## Example

      # Custom current-user logic, e.g. in old versions of phx.gen.auth
      @impl true
      def fetch_subject(_socket, session) do
        # Fetch and return the current user directly
        user_token = session["user_token"]
        user_token && MyApp.Accounts.get_user_by_session_token(user_token)
      end
  """
  @callback fetch_subject(PhoenixTypes.socket(), map()) :: Types.subject()

  @doc ~S"""
  Configures the controller with the application's authorization configuration.

  ## Example

      # Recommended: configure using a keyword in `use` - recommended in the main web module
      defmodule MyAppWeb do
        def live_view do
          quote do
            use Permit.Phoenix.LiveView,
              authorization_module: MyApp.Authorization
              # other options...
          end
        end
      end

      # Alternatively, implement directly in the live view module (e.g. to override)
      @impl Permit.Phoenix.LiveView
      def authorization_module, do: MyApp.Authorization

      # Requires defining an authorization configuration module
      defmodule MyApp.Authorization, do:
        use Permit.Ecto,
          permissions_module: MyApp.Permissions,
          repo: MyApp.Repo
  """
  @callback authorization_module() :: Types.authorization_module()

  @doc ~S"""
  Declares which actions in the LiveView should skip automatic record preloading.

  By default, all actions preload records automatically. Actions in `skip_preload/0` will
  only authorize against the resource module, not specific records. This is useful for
  actions like `:create` and `:new` where there's no existing record to load.

  Defaults to `[:create, :new]`.

  Note that the `:update` action is a special case in default LiveView usage, as it is
  typically used to update a record with form data. In this case, the record is not loaded
  and authorized, but rather reloaded and re-authorized, to ensure permissions are evaluated
  against the latest data.

  You can disable this behaviour by overriding `reload_on_event?/2` (or by passing the
  `:reload_on_event?` option) if you prefer to reuse the already assigned record.

  ## Example

      @impl true
      def skip_preload do
        [:create, :new, :bulk_action]
      end
  """
  @callback skip_preload() :: list(Types.action_group())

  @doc ~S"""
  **Deprecated:** Use `c:skip_preload/0` instead.

  Declares which actions in the LiveView are to use Permit's automatic preloading and
  authorization in addition to defaults: `[:show, :edit, :update, :delete, :index]`.

  This callback is deprecated in favor of `c:skip_preload/0` which inverts the logic - instead of
  whitelisting actions that preload, you blacklist actions that should skip preloading.

  ## Example

      # Declare that the `:view` live action should be preloaded and authorized
      @impl true
      def preload_actions, do: super() ++ [:view]

      @impl true
      def handle_params(_params, _uri, %{assigns: %{live_action: :view}} = socket) do
        # authorized record is in `assigns.loaded_resource`
        {:noreply, socket}
      end
  """
  @callback preload_actions() :: list(Types.action_group())

  @doc ~S"""
  Sets the fallback path to which the user is redirected on authorization failure unless
  it is possible to remain on the same page (i.e. if the LiveView is mounted directly
  via the router).

  **Ignored** if `handle_unauthorized/2` has a custom implementation.

  Defaults to `/`.

  ## Example

      # Recommended: set a fallback path for all LiveViews
      defmodule MyAppWeb do
        def live_view do
          quote do
            use Permit.Phoenix.LiveView,
              fallback_path: "/unauthorized",
              # other options...
          end
        end
      end

      # Set a fallback path for a specific LiveView
      defmodule MyAppWeb.PageLive do
        use MyAppWeb, :live_view

        @impl true
        def fallback_path(action, socket), do: "/unauthorized"
      end
  """
  @callback fallback_path(Types.action_group(), PhoenixTypes.socket()) :: binary()

  @doc ~S"""
  Allows opting out of using Permit for given LiveView actions.

  Defaults to `[]`, thus by default all actions are guarded with Permit.

  ## Example

      @impl true
      def except, do: [:index]
  """
  @callback except() :: list(Types.action_group())

  @doc ~S"""

  If `Permit.Ecto` is not used, it allows defining a loader function that loads a record
  or a list of records, depending on action type (singular or plural).

  In the argument, the resolution context is passed, which contains the action, params, socket, etc.

  ## Example

      @impl true
      def loader(%{action: :index, params: %{page: page}}),
        do: ItemContext.load_all(page: page)
  """
  @callback loader(Types.resolution_context()) :: Types.object() | nil

  @doc ~S"""
  Called when a record is not found. When using Permit.Ecto, this callback is called when both of
  the following queries return no results:
  - the query constructed with: the record ID, `c:base_query/1`, and the authorization conditions,
  - a second query that only contains the record ID and `c:base_query/1`.
  This is to distinguish between authorization failure and record-not-found scenarios.

  When a loader function is defined instead of using Permit.Ecto, authorization conditions are only
  checked directly on the loaded record (or all of the loaded records in a list), so this callback is
  unambiguously called when the loader function has returned `nil`.

  Defaults to raising a `Permit.Phoenix.RecordNotFoundError`.

  ## Example

      @impl true
      def handle_not_found(socket) do
        {:noreply, socket |> put_flash(:error, "Record not found")}
      end
  """
  @callback handle_not_found(PhoenixTypes.socket()) :: PhoenixTypes.hook_outcome()

  @doc ~S"""
  Sets the name of the ID param that will be used for preloading a record for authorization.

  Defaults to `"id"`. If the route contains a different name of the record ID param, it should be changed accordingly.

  ## Example

      # Recommended: set a default ID param name for all LiveViews
      defmodule MyAppWeb do
        def live_view do
          quote do
            use Permit.Phoenix.LiveView,
              id_param_name: "uuid",
              # other options...
          end
        end
      end

      # Set for a single LiveView
      @impl true
      def id_param_name(_action, _socket), do: "uuid"
  """
  @callback id_param_name(Types.action_group(), PhoenixTypes.socket()) :: binary()

  @doc ~S"""
  Sets the name of the field that contains the resource's ID which should be looked for.

  Defaults to `:id`. If the record's ID (usually a primary key) is in a different field, then it should be changed accordingly.

  ## Example

      # Recommended: set a default ID struct field name for all LiveViews
      defmodule MyAppWeb do
        def live_view do
          quote do
            use Permit.Phoenix.LiveView,
              id_struct_field_name: :uuid
          end
        end
      end

      # Set for a single LiveView
      @impl true
      def id_struct_field_name(_action, _socket), do: :uuid
  """
  @callback id_struct_field_name(Types.action_group(), PhoenixTypes.socket()) :: atom()

  @doc ~S"""
  Sets the flash message to display when authorization fails.

  **Ignored** if `handle_unauthorized/2` has a custom implementation.

  Defaults to `"You do not have permission to perform this action."`.

  ## Example

      @impl true
      def unauthorized_message(action, socket), do: "Thou shalt not pass."
  """
  @callback unauthorized_message(PhoenixTypes.socket(), map()) :: binary()

  @doc ~S"""
  Provides a mapping of event names (e.g. `"save"`) to Permit actions (e.g. `:create` or `:update`).

  **It is recommended to use `@permit_action` module attribute instead of this callback.** The purpose
  of this callback remaining is that, when the event handler is not defined using pattern matching
  on the event name, the module attribute cannot infer the event name from the function header -
  in which case the callback should be used to provide an unambiguous mapping.

  Note that calling this function will return its user-implemented form **merged with additional
  mappings defined using `@permit_action` module attribute**, as they are consumed using
  `__before_compile__/1`. Because of this, `super` will not work - to augment the default mapping,
  you need to call and merge into `Permit.Phoenix.LiveView.default_event_mapping/0`.

  ## Example

      # Not recommended: event handler doesn't pattern match on the event name
      @impl true
      def handle_event(event_name, params, socket) do
        custom_logic(event_name, params, socket)
      else

      @impl true
      def event_mapping, do: %{
        "save" => :create,
        "update" => :update
      }

      # Recommended: use @permit_action module attribute
      @impl true
      @permit_action :create
      def handle_event("save", params, socket) do
        # ...
      end

      @impl true
      @permit_action :update
      def handle_event("update", params, socket) do
        # ...
      end
  """
  @callback event_mapping() :: map()

  @doc ~S"""
  For events that do not carry an `"id"` param (e.g. updating a record with form data), determines whether to reload the record before each event authorization.

  Defaults to `true`.

  ## Example

      @impl true
      def reload_on_event?(_action, _socket) do
        true
      end
  """
  @callback reload_on_event?(Types.action_group(), PhoenixTypes.socket()) :: boolean()

  @doc ~S"""
  Determines whether to use Phoenix Streams for plural actions (e.g. `:index`), or to assign
  the resources to the `:loaded_resources` assign.

  Defaults to `false`, which means that the resources will be assigned to `:loaded_resources`.

  ## Example

      # Recommended: set a default use_stream? for all LiveViews
      defmodule MyAppWeb do
        def live_view do
          quote do
            use Permit.Phoenix.LiveView,
              use_stream?: true,
              # other options...
          end
        end
      end

      # Set for a single LiveView
      @impl true
      def use_stream?(socket), do: true
  """
  @callback use_stream?(PhoenixTypes.socket()) :: boolean()

  @doc ~S"""
  Determines whether to use Phoenix Scopes for fetching the subject. Set to `false` in Phoenix <1.8.

  If `true`, the subject will be fetched from `current_scope.user`. If `false`, the subject will be
  fetched from `current_user` assign.

  Defaults to `true`.

  ## Example

      # Recommended: set for all LiveViews
      defmodule MyAppWeb do
        def live_view do
          quote do
            use Permit.Phoenix.LiveView,
              use_scope?: false,
              # other options...
            end
          end
        end
      end

      # Set for a single LiveView
      @impl true
      def use_scope? do
        false
      end
  """
  @callback use_scope?() :: boolean()

  @doc ~S"""
  Maps the current Phoenix scope to the subject, if Phoenix Scopes are used (see the `use_scope?/0` callback). Defaults to `scope.user`.

  Defaults to `:user`.

  ## Example

      # Recommended: set a default scope_subject for all LiveViews
      defmodule MyAppWeb do
        def live_view do
          quote do
            use Permit.Phoenix.LiveView,
              # as an atom
              scope_subject: :user,
              # or as a captured function
              scope_subject: &SomeModule.some_function/1,
              # other options...
            end

            # Can also be given as a callback implementation
            @impl true
            def scope_subject(scope), do: scope.user
          end
        end
      end

      # Set for a single LiveView
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
                        skip_preload: 0,
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
                        reload_on_event?: 2,
                        use_scope?: 0,
                        scope_subject: 1
                      ]
                      |> Enum.filter(& &1)

  defmacro __using__(opts) do
    # credo:disable-for-next-line
    quote generated: true do
      import unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :permit_action, accumulate: true)
      Module.register_attribute(__MODULE__, :__event_mapping__, [])
      @__event_mapping__ %{}
      @on_definition Permit.Phoenix.Decorators.LiveView

      if unquote(@permit_ecto_available?) do
        require Ecto.Query
      end

      @behaviour unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      @opts unquote(opts)

      # event mapping is defined in the __before_compile__ callback to ensure it is
      # available to the module before the __before_compile__ callback is executed.
      @before_compile unquote(__MODULE__)

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
      def skip_preload do
        unquote(__MODULE__).skip_preload(unquote(opts))
      end

      @impl true
      def preload_actions,
        do: (unquote(opts[:preload_actions]) || []) ++ [:show, :edit, :index, :delete, :update]

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
      def reload_on_event?(action, socket) do
        case unquote(opts[:reload_on_event?]) do
          fun when is_function(fun) -> fun.(action, socket)
          value when value in [nil, true] -> true
          false -> false
          _ -> raise ":reload_on_event? must be a function or a boolean"
        end
      end

      @impl true
      def use_scope? do
        case unquote(opts[:use_scope?]) do
          fun when is_function(fun) -> fun.()
          value when value in [nil, true] -> true
          false -> false
          _ -> raise ":use_scope? must be a function or a boolean"
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
          skip_preload: 0,
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
          use_scope?: 0,
          scope_subject: 1,
          reload_on_event?: 2
        ]
        |> Enum.filter(& &1)
      )
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      if Module.defines?(__MODULE__, {:event_mapping, 0}) do
        # it appears the developer has defined their own event_mapping/0 function,
        # so we will disregard the default event mapping, and only merge the developer's
        # implementation with whatever was defined using @permit_action module attributes.
        defoverridable event_mapping: 0
        def event_mapping, do: super() |> Map.merge(@__event_mapping__)
      else
        # no event_mapping/0 function defined, so we use the default event mapping + whatever
        # was defined in the module using @permit_action.
        @impl true
        def event_mapping,
          do: unquote(__MODULE__).default_event_mapping() |> Map.merge(@__event_mapping__)

        defoverridable event_mapping: 0
      end

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

  @doc ~S"""
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

  @doc ~S"""
  Default event mapping will not map "save" to any action. It is not unambiguous
  whether "save" should be mapped to :create or :update. Since Phoenix generators use "save"
  for both create and update actions, it will be up to the developer to clarify the mapping.

      @permit_action :create
      def handle_event("save", params, socket) do
        {:noreply, socket}
      end

      @permit_action :update
      def handle_event("save", params, socket) do
        {:noreply, socket}
      end

  Default event name to action name mapping is:

      %{
        "create" => :create,
        "delete" => :delete,
        "edit" => :edit,
        "index" => :index,
        "new" => :new,
        "show" => :show,
        "update" => :update
      }
  """
  def default_event_mapping do
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

  @doc false
  def unauthorized_message(action, socket, opts) do
    case opts[:unauthorized_message] do
      nil -> "You do not have permission to perform this action."
      fun when is_function(fun) -> fun.(action, socket)
      msg -> msg
    end
  end

  @doc false
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
  defdelegate skip_preload(opts), to: Permit.Phoenix.CommonOpts

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
