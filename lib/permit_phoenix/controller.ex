defmodule Permit.Phoenix.Controller do
  @moduledoc ~S"""
  Configures and injects the authorization plug for Phoenix controllers.

  ## Mechanism overview

  Permit.Phoenix.Controller uses an internal plug module that does the following:
  1. Get everything needed to authorize the current action:
     - **Action** - from current controller action name, e.g. `:update` or `:index`,
     - **Resource module** - from the controller module configuration (`:resource_module` Plug option), e.g. `MyApp.Article`
     - **Subject** - from `@current_user`, `@current_scope.user` or whatever else is configured.
  2. In "many" actions (e.g. `:index`):
     - Check for permission to perform the action on the resource module.
     - If authorized, load the list of records using Ecto (queried by authorization conditions), or a custom laoder function,
      and assign the filtered list to `@loaded_resources`.
  3. In "one" actions (e.g. `:update`):
     - Load the resource using Ecto (queried by authorization conditions and the `"id"` param, by default) or a custom
      loader function,
     - Check authorization conditions on the loaded resource. If authorized, assign the resource to `@loaded_resource`.
  4. Handle authorization failure:
     - Call `c:handle_unauthorized/2` callback if unauthorized, which defaults to redirecting to `c:fallback_path/2`.
     - Call `c:handle_not_found/1` callback if the resource is not found, which defaults to raising `Permit.Phoenix.RecordNotFoundError`.

  ## Usage

  Basic setup:

  ```
  defmodule MyAppWeb.ArticleController do
    use MyAppWeb, :controller

    use Permit.Phoenix.Controller,
      authorization_module: MyApp.Authorization,
      resource_module: MyApp.Article

    def index(conn, params) do
      # @loaded_resources is assigned if authorized, containing filtered records
    end

    def show(conn, params) do
      # @loaded_resource is assigned if authorized
    end
  end
  ```

  It is recommended to set it up in your app's main web module and then override specific options in individual
  controllers.:

  ```
  defmodule MyAppWeb do
    def controller do
      quote do
        use Permit.Phoenix.Controller,
          authorization_module: MyApp.Authorization
      end
    end
  end

  defmodule MyAppWeb.ArticleController do
    use MyAppWeb, :controller

    # Set the resource module for this controller
    @impl true
    def resource_module, do: MyApp.Article

    # Controller actions...
  end
  ```

  Handling authorization failure can be customized at several levels:

  ### Customize the fallback path and error message

  By default, the plug will redirect to the fallback path and display a flash message with the default error message.

  ```
  @impl true
  def fallback_path(action, conn) do
    # Default implementation
    "/"
  end

  @impl true
  def unauthorized_message(action, conn) do
    # Default implementation
    "You are not authorized to perform this action"
  end
  ```

  ### Fully customize error handling behaviour

  Optionally, you can fully customize the error handling behaviour by implementing the `c:handle_unauthorized/2`
  and `c:handle_not_found/1` callbacks. These are also available as keyword options, but not recommended.

  ```
  use Permit.Phoenix.Controller,
    authorization_module: MyApp.Authorization,
    resource_module: MyApp.Article

  @impl true
  def handle_unauthorized(action, conn) do
    # Default implementation
    conn
    |> put_flash(:error, "You are not authorized to perform this action")
    |> redirect(to: "/")
    |> halt()
  end

  @impl true
  def handle_not_found(conn) do
    # Default implementation
    raise Permit.Phoenix.RecordNotFoundError, "Expected at least one result but got none"
  end
  ```

  ### Ecto query generation

  Permit.Phoenix uses Permit.Ecto to convert defined permissions into Ecto queries. For example, if there is a permission
  to `delete(Article, author_id: user_id, draft: true)`, inside the `delete` controller action
  it will generate a `WHERE article.author_id = $1 AND draft = TRUE` query. All operators defined in `Permit.Operators`
  are supported - for reference, see [`Permit.Operators` documentation](https://hexdocs.pm/permit/Permit.Operators.html).

  In actions routed via a parent resource, you need to customize the Ecto query to filter records by the parent resource ID.
  For this purpose, `c:base_query/1` callback is available; you can also use the `finalize_query/2` callback to post-process
  the query.

  ```
  defmodule MyAppWeb.CommentController do
    use MyAppWeb, :controller

    use Permit.Phoenix.Controller,
      authorization_module: MyApp.Authorization,
      resource_module: MyApp.Article

    @impl true
    def base_query(%{action: :index, params: %{"article_id" => article_id}} = context) do
      # Chain the originally constructed query with a custom query to filter by the parent resource ID
      super(context)
      |> MyApp.CommentQueries.by_article_id(article_id)
    end

    def index(conn, params) do
      # @loaded_resources is assigned if authorized, records filtered by both the parent resource ID
      # and the current user's permissions
    end
  end
  ```

  ## Controller and Permit actions

  Controller actions are mapped to permission action names in the following order:
  1. via the `c:action_grouping/0` callback,
  2. as configured in your app's `Permit.Phoenix.Actions` implementation.

  Likewise, Permit determines which actions need to preload a single record (e.g. `:show`)
  or a list of records (e.g. `:index`) in the following order:
  1. via the `c:singular_actions/0` callback,
  2. as configured in your app's `Permit.Phoenix.Actions` implementation.

  Default singular actions are `[:show, :edit, :new, :delete, :update]`, any other action
  is plural by default. By default, all actions preload records except those in `c:skip_preload/0`
  (`:create` and `:new` by default, as there's nothing to preload for these actions).
  Implementing `c:skip_preload/0` allows opting out of preloading records for chosen actions,
  in which case only the resource name is authorized against.

  By default, `Permit.Phoenix.Actions` defines the following convenience shorthands:
  - `:index` and `:show` controller actions are authorized with the `:read` permission,
  - `:new` and `:create` controller actions are authorized with the `:create` permission,
  - `:edit` and `:update` controller actions are authorized with the `:update` permission.
  - `:delete` action is defined as standalone.
  See `Permit.Phoenix.Actions` documentation for more details on action grouping.

  It is recommended to have the actions module read action names from the router, so that
  your permissions module has convenience functions for using each action.

  ```
  defmodule MyApp.Actions do
    # Merge the actions from the router into the default grouping schema.
    use Permit.Phoenix.Actions, router: MyApp.Router
  end
  ```

  ## Options

  For reference regarding the options, see callback documentation below.

  In `use` keywords, options correspond to callback names and can be defined as:
  - literal expressions,
  - captured functions that match the corresponding callback signature. Anonymous functions
  are not supported because of compiler limitations.
  """

  alias Permit.Phoenix.Types, as: PhoenixTypes
  alias Permit.Types
  alias Permit.Phoenix.RecordNotFoundError

  import Plug.Conn
  import Phoenix.Controller

  @permit_ecto_available? Permit.Phoenix.Utils.permit_ecto_available?()

  @doc ~S"""
  Configures the controller with the application's authorization configuration.

  ## Example

      @impl Permit.Phoenix.Controller
      def authorization_module, do: MyApp.Authorization

      # Requires defining an authorization configuration module
      defmodule MyApp.Authorization, do:
        use Permit, permissions_module: MyApp.Permissions
  """
  @callback authorization_module() :: Types.authorization_module()

  @doc """
  Defines the action grouping schema for this controller.
  This can be overridden in individual controllers to customize the action mapping.

  ## Example

      @impl true
      def action_grouping do
        %{
          new: [:create],
          index: [:read],
          show: [:read],
          edit: [:update],
          create: [:create],
          update: [:update],
          delete: [:delete]
        }
      end
  """
  @callback action_grouping() :: map()

  @doc """
  Defines which actions are considered singular (operating on a single resource).
  This can be overridden in individual controllers to customize the singular actions.

  ## Example

      @impl true
      def singular_actions do
        [:show, :edit, :new, :delete, :update]
      end
  """
  @callback singular_actions() :: [atom()]

  @doc ~S"""
  Declares the controller's resource module. For instance, when Phoenix and Ecto is used, typically for an `ArticleController` the resource will be an `Article` Ecto schema.

  This resource module, along with the controller action name, will be used for authorization checks before each action.

  If `Permit.Ecto` is used, this setting selects the Ecto schema which will be used for automatic preloading a record for authorization.

  ## Example

      defmodule MyApp.ArticleController do
        use Permit.Phoenix.Controller

        def authorization_module, do: MyApp.Authorization

        def resource_module, do: MyApp.Article

        # Alternatively, you can do the following:

        use Permit.Phoenix.Controller,
          authorization_module: MyApp.Authorization,
          resource_module: MyApp.Blog.Article
      end
  """
  @callback resource_module() :: Types.resource_module()

  if @permit_ecto_available? do
    @doc ~S"""
    Creates the basis for an Ecto query constructed by `Permit.Ecto` based on controller action,
    resource module, subject (taken from `current_scope.user` unless configured otherwise)
    and controller params.

    It's recommended to call `super(arg)` in your implementation to ensure proper
    base query handling for both singular actions (like :show, which need ID filtering)
    and plural actions (like :index, which may handle delete events).

    Typically useful when using [nested resource routes](https://hexdocs.pm/phoenix/routing.html#nested-resources).
    In an action routed like `/users/:user_id/posts/:id`, you can use the `c:base_query/1` callback to
    filter records by `user_id`, while filtering by `id` itself will be applied automatically
    (the name of the ID parameter can be overridden with the `c:id_param_name/2` callback).

    ## Example

        defmodule MyApp.CommentController do
          use Permit.Phoenix.Controller,
            authorization_module: MyApp.Authorization
            resource_module: MyApp.Blog.Comment

          @impl true
          def base_query(%{
            action: :index,
            params: %{"article_id" => article_id}
          }) do
            MyApp.CommentQueries.by_article_id(article_id)
          end
        end
    """
    @callback base_query(Types.resolution_context()) :: Ecto.Query.t()

    @doc ~S"""
    Post-processes an Ecto query constructed by `Permit.Ecto`. Usually, `c:base_query/1` should
    be used; the only case when `c:finalize_query/2` should be used is when you need to modify the query
    based on conditions derived from the generated query structure.

    ## Example

        defmodule MyApp.CommentController do
          use Permit.Phoenix.Controller,
            authorization_module: MyApp.Authorization
            resource_module: MyApp.Blog.Comment

          # just for demonstration - please don't do it directly in controllers
          import Ecto.Query

          @impl true
          def finalize_query(query, %{
            action: :index,
          }) do
            query
            |> preload([c], [:user])
          end
        end
    """
    @callback finalize_query(Ecto.Query.t(), Types.resolution_context()) :: Ecto.Query.t()
  end

  @doc ~S"""
  Called when authorization on an action or a loaded record is not granted. Must halt `conn` after rendering or redirecting.

  ## Example

      @impl true
      def handle_unauthorized(action, conn) do
        case get_format(conn) do
          "json" ->
            # render a 4xx JSON response

          "html" ->
            # handle HTML response, e.g. redirect
        end
      end
  """
  @callback handle_unauthorized(Types.action_group(), PhoenixTypes.conn()) :: PhoenixTypes.conn()

  @doc ~S"""
  Retrieves the authorization subject from `conn`. Defaults to `current_scope.user` if `use_scope?/0` is `true`,
  otherwise `conn.assigns[:current_user]`.

  ## Example

      @impl true
      def fetch_subject(%{assigns: assigns}) do
        assigns[:user]
      end
  """
  @callback fetch_subject(PhoenixTypes.conn()) :: Types.subject()

  @doc ~S"""
  Declares which actions in the controller should skip automatic record preloading.

  By default, all actions preload records automatically. Actions in `skip_preload/0` will
  only authorize against the resource module, not specific records. This is useful for
  actions like `:create` and `:new` where there's no existing record to load.

  Defaults to `[:create, :new]`.

  ## Example

      @impl true
      def skip_preload do
        [:create, :new, :bulk_action]
      end
  """
  @callback skip_preload() :: list(Types.action_group())

  @doc ~S"""
  **Deprecated:** Use `c:skip_preload/0` instead.

  Declares which actions in the controller are to use Permit's automatic preloading and authorization.
  This callback is deprecated in favor of `c:skip_preload/0` which inverts the logic - instead of
  whitelisting actions that preload, you blacklist actions that should skip preloading.

  ## Example

      @impl true
      def preload_actions do
        [:view]
      end
  """
  @callback preload_actions() :: list(Types.action_group())

  @doc ~S"""
  If `c:handle_unauthorized/2` is not customized, sets the fallback path to which the user is redirected
  on authorization failure.

  Defaults to `/`.

  ## Example

      @impl true
      def fallback_path(action, conn) do
        case action do
          :view -> "/unauthorized"
          _ -> "/"
        end
      end
  """
  @callback fallback_path(Types.action_group(), PhoenixTypes.conn()) :: binary()

  @doc ~S"""
  Allows opting out of using Permit for given controller actions.

  Defaults to `[]`, thus by default all actions are guarded with Permit.

  ## Example

      @impl true
      def except do
        [:index]
      end
  """
  @callback except() :: list(Types.action_group())

  @doc ~S"""
  If `Permit.Ecto` is not used, it allows defining a loader function that loads a record
  or a list of records, depending on action type (singular or plural).

  In the argument, the resolution context is passed, which contains the action, params, conn, etc.

  ## Example

      @impl true
      def loader(%{action: :index, params: %{page: page}}),
        do: ItemContext.load_all(page: page)

      def loader(%{action: :show}, params: %{id: id}),
        do: ItemContext.load(id)
  """
  @callback loader(Types.resolution_context()) :: Types.object() | nil

  @doc ~S"""
  Sets the name of the ID param that will be used for preloading a record for authorization.

  Defaults to `"id"`. If the route contains a different name of the record ID param, it should be changed accordingly.

  ## Example

      @impl true
      def id_param_name(_action, _conn) do
        "document"
      end
  """
  @callback id_param_name(Types.action_group(), PhoenixTypes.conn()) :: binary()

  @doc ~S"""
  Sets the name of the field that contains the resource's ID which should be looked for.

  Defaults to `:id`. If the record's ID (usually a primary key) is in a different field, then it should be changed accordingly.

  ## Example

      @impl true
      def id_struct_field_name(_action, _conn) do
        :uuid
      end
  """
  @callback id_struct_field_name(Types.action_group(), PhoenixTypes.conn()) :: atom()

  @doc ~S"""
  Called when a record is not found.

  Defaults to raising a `Permit.Phoenix.RecordNotFoundError`.

  ## Example

      @impl true
      def handle_not_found(conn) do
        case get_format(conn) do
          "json" ->
            # render a 4xx JSON response

          "html" ->
            # handle HTML response, e.g. redirect
        end
      end
  """
  @callback handle_not_found(PhoenixTypes.conn()) :: PhoenixTypes.conn()

  @doc ~S"""
  If `c:handle_unauthorized/2` is not customized, sets the error message to display when authorization fails.

  Defaults to `"You do not have permission to perform this action."`.

  ## Example

      @impl true
      def unauthorized_message(action, conn) do
        "You cannot #{action} this article"
      end
  """
  @callback unauthorized_message(Types.action_group(), PhoenixTypes.conn()) :: binary()

  @doc ~S"""
  Determines whether to use Phoenix Scopes for fetching the subject.

  If `true`, the subject will be fetched from `current_scope.user` assign. If `false`, the subject will be
  fetched from `current_user` assign.

  Defaults to `true`, must be set to `false` in Phoenix <1.8 or when you've migrated your code from
  an earlier Phoenix version.

  ## Example

      @impl true
      def use_scope? do
        false
      end
  """
  @callback use_scope?() :: boolean()

  @doc ~S"""
  Maps the current Phoenix scope to the subject, if Phoenix Scopes are used (see the `use_scope?/0` callback).
  Defaults to `scope.user`.

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
                        skip_preload: 0,
                        preload_actions: 0,
                        fallback_path: 2,
                        resource_module: 0,
                        except: 0,
                        fetch_subject: 1,
                        loader: 1,
                        handle_not_found: 1,
                        unauthorized_message: 2,
                        use_scope?: 0,
                        scope_subject: 1
                      ]
                      |> Enum.filter(& &1)

  defmacro __using__(opts) do
    quote generated: true do
      require Logger

      @behaviour unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      @opts unquote(opts)

      @impl true
      def handle_unauthorized(action, conn) do
        unquote(__MODULE__).handle_unauthorized(action, conn, unquote(opts))
      end

      @impl true
      def handle_not_found(conn) do
        unquote(__MODULE__).handle_not_found(conn, unquote(opts))
      end

      @impl true
      def unauthorized_message(action, conn) do
        unquote(__MODULE__).unauthorized_message(action, conn, unquote(opts))
      end

      @impl true
      def authorization_module,
        do:
          unquote(opts[:authorization_module]) ||
            raise(":authorization_module option must be given when using ControllerAuthorization")

      @impl true
      def resource_module, do: unquote(opts[:resource_module])

      @impl true
      def skip_preload do
        unquote(__MODULE__).skip_preload(unquote(opts))
      end

      @impl true
      def preload_actions do
        unquote(__MODULE__).preload_actions(unquote(opts))
      end

      @impl true
      def fallback_path(action, conn) do
        unquote(__MODULE__).fallback_path(action, conn, unquote(opts))
      end

      @impl true
      def except do
        unquote(__MODULE__).except(unquote(opts))
      end

      if unquote(@permit_ecto_available?) do
        @impl true
        def base_query(%{
              action: action,
              resource_module: resource_module,
              conn: conn,
              params: params
            }) do
          param = id_param_name(action, conn)
          field = id_struct_field_name(action, conn)

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
      def id_param_name(action, conn) do
        unquote(__MODULE__).id_param_name(action, conn, unquote(opts))
      end

      @impl true
      def id_struct_field_name(action, conn) do
        unquote(__MODULE__).id_struct_field_name(action, conn, unquote(opts))
      end

      @impl true
      def fetch_subject(conn) do
        unquote(__MODULE__).fetch_subject(conn, unquote(opts))
      end

      @impl true
      def action_grouping do
        Permit.Phoenix.Actions.grouping_schema()
      end

      @impl true
      def singular_actions do
        unquote(opts)[:authorization_module].permissions_module().actions_module().singular_actions()
      end

      @impl true
      def use_scope? do
        unquote(__MODULE__).use_scope?(unquote(opts))
      end

      @impl true
      def scope_subject(scope) do
        unquote(__MODULE__).scope_subject(scope, unquote(opts))
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
          fetch_subject: 1,
          id_param_name: 2,
          id_struct_field_name: 2,
          handle_not_found: 1,
          unauthorized_message: 2,
          action_grouping: 0,
          singular_actions: 0
        ]
        |> Enum.filter(& &1)
      )

      plug(Permit.Phoenix.Plug)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      if Module.defines?(__MODULE__, {:loader, 1}) do
        @loader_defined? true
      else
        @loader_defined? false
        @impl true
        def loader(resolution_context) do
          unquote(__MODULE__).loader(resolution_context, @opts)
        end
      end

      # Internal function to expose loader_defined? at runtime for Permit.Phoenix.Plug
      @doc false
      def __permit_loader_defined__?, do: @loader_defined?
    end
  end

  @doc false
  def handle_unauthorized(action, conn, _opts) do
    conn
    |> put_flash(:error, controller_module(conn).unauthorized_message(action, conn))
    |> redirect(to: controller_module(conn).fallback_path(action, conn))
    |> halt()
  end

  @doc false
  def handle_not_found(_conn, _opts) do
    raise RecordNotFoundError, "Expected at least one result but got none"
  end

  @doc false
  def fallback_path(action, conn, opts) do
    case opts[:fallback_path] do
      nil -> "/"
      fun when is_function(fun) -> fun.(action, conn)
      path -> path
    end
  end

  @doc false
  def unauthorized_message(action, conn, opts) do
    case opts[:unauthorized_message] do
      nil -> "You do not have permission to perform this action."
      fun when is_function(fun) -> fun.(action, conn)
      msg -> msg
    end
  end

  @doc false
  def skip_preload(opts) do
    cond do
      # skip_preload option takes precedence
      is_list(opts[:skip_preload]) ->
        opts[:skip_preload]

      # deprecated: if preload_actions is set, emit warning and convert to skip_preload
      is_list(opts[:preload_actions]) ->
        IO.warn(
          "The :preload_actions option is deprecated. Use :skip_preload instead. " <>
            "Actions not in skip_preload will automatically preload records.",
          Macro.Env.stacktrace(__ENV__)
        )

        # Can't reliably convert preload_actions to skip_preload, so we return default
        [:create, :new]

      # default
      true ->
        [:create, :new]
    end
  end

  @doc false
  @deprecated "Use skip_preload/1 instead"
  def preload_actions(opts) do
    case opts[:preload_actions] do
      nil -> [:show, :edit, :update, :delete, :index]
      list when is_list(list) -> list ++ [:show, :edit, :update, :delete, :index]
    end
  end

  @doc false
  def except(opts) do
    case opts[:except] do
      nil -> []
      except -> except
    end
  end

  if @permit_ecto_available? do
    @doc false
    def base_query(
          %{
            action: action,
            resource_module: resource_module,
            conn: conn,
            params: params
          },
          opts
        ) do
      param = __MODULE__.id_param_name(action, conn, opts)
      field = __MODULE__.id_struct_field_name(action, conn, opts)

      case params do
        %{^param => id} ->
          apply(Permit.Ecto, :filter_by_field, [resource_module, field, id])

        _ ->
          apply(Permit.Ecto, :from, [resource_module])
      end
    end

    @doc false
    def finalize_query(query, %{}, _), do: query
  end

  @doc false
  def loader(resolution_context, opts) do
    case opts[:loader] do
      nil -> nil
      function -> function.(resolution_context)
    end
  end

  @doc false
  def id_param_name(action, conn, opts) do
    case opts[:id_param_name] do
      nil -> "id"
      param_name when is_binary(param_name) -> param_name
      param_name_fn when is_function(param_name_fn) -> param_name_fn.(action, conn)
    end
  end

  @doc false
  def id_struct_field_name(action, conn, opts) do
    case opts[:id_struct_field_name] do
      nil ->
        :id

      struct_field_name when is_binary(struct_field_name) ->
        struct_field_name

      struct_field_name_fn when is_function(struct_field_name_fn) ->
        struct_field_name_fn.(action, conn)
    end
  end

  @doc false
  def use_scope?(opts) do
    case opts[:use_scope?] do
      fun when is_function(fun) -> fun.() || true
      nil -> true
      other -> other
    end
  end

  @doc false
  def scope_subject(scope, opts) do
    case opts[:scope_subject] do
      fun when is_function(fun) -> fun.(scope)
      nil -> scope.user
      key -> scope |> Map.fetch!(key)
    end
  end

  @doc false
  def fetch_subject(conn, opts) do
    fetch_subject_fn = opts[:fetch_subject_fn]

    cond do
      is_function(fetch_subject_fn, 1) -> fetch_subject_fn.(conn)
      use_scope?(opts) -> scope_subject(conn.assigns[:current_scope], opts)
      true -> conn.assigns[:current_user]
    end
  end
end
