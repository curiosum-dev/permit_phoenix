defmodule Permit.Phoenix.Controller do
  @moduledoc """
  Injects authorization plug (Permit.Phoenix.Plug), allowing to
  provide its options either directly in options of `use`, or
  as overridable functions.

  Example:

      # my_app_web.ex
      def controller do
        use Permit.Phoenix.Controller,
          authorization_module: MyApp.Authorization,
          fallback_path: "/unauthorized"
      end

      # your controller module
      defmodule MyAppWeb.PageController do
        use MyAppWeb, :live_view

        @impl true
        def resource_module, do: MyApp.Item

        # you might or might not want to override something here

        @impl true
        def fallback_path: "/foo"
      end

  """
  alias Permit.Phoenix.Types, as: PhoenixTypes
  alias Permit.Types

  import Plug.Conn
  import Phoenix.Controller

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

  if :ok == Application.ensure_loaded(:permit_ecto) do
    @doc ~S"""
    Creates the basis for an Ecto query constructed by `Permit.Ecto` based on controller action, resource module, subject (typically `:current_user`) and controller params.

    Typically useful when using [nested resource routes](https://hexdocs.pm/phoenix/routing.html#nested-resources). In an action routed like `/users/:user_id/posts/:id`, you can use the `c:base_query/1` callback to filter records by `user_id`, while filtering by `id` itself will be applied automatically (the name of the ID parameter can be overridden with the `c:id_`).

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
    Post-processes an Ecto query constructed by `Permit.Ecto` based on controller action, resource module, subject (typically `:current_user`) and controller params.

    Typically useful when using [nested resource routes](https://hexdocs.pm/phoenix/routing.html#nested-resources). In an action routed like `/users/:user_id/posts/:id`, you can use the `c:base_query/1` callback to filter records by `user_id`, while filtering by `id` itself will be applied automatically (the name of the ID parameter can be overridden with the `c:id_`).

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

      defmodule MyApp.CommentController do
        use Permit.Phoenix.Controller,
          authorization_module: MyApp.Authorization
          resource_module: MyApp.Blog.Comment

        @impl true
        def handle_unauthorized(action, conn) do
          case get_format(conn) do
            "json" ->
              # render a 4xx JSON response

            "html" ->
              # handle HTML response, e.g. redirect
          end
        end
      end
  """
  @callback handle_unauthorized(Types.action_group(), PhoenixTypes.conn()) :: PhoenixTypes.conn()

  @doc ~S"""
  Retrieves the current user from `conn` as the authorization subject. Defaults to `conn.assigns[:current_user]`.

  ## Example

      @impl true
      def fetch_subject(%{assigns: assigns}) do
        assigns[:user]
      end
  """
  @callback fetch_subject(PhoenixTypes.conn()) :: Types.subject()

  @doc ~S"""
  Declares which actions in the controller are to use Permit's automatic preloading and authorization in addition to defaults: `[:show, :edit, :update, :delete, :index]`.

  Defaults to `[]`, which means that `[:show, :edit, :update, :delete, :index]` and no other actions will use preloading.
  """
  @callback preload_actions() :: list(Types.action_group())

  @doc ~S"""
  If `c:handle_unauthorized/2` is not defined, sets the fallback path to which the user is redirected on authorization failure.

  Defaults to `/`.
  """
  @callback fallback_path(Types.action_group(), PhoenixTypes.conn()) :: binary()

  @doc ~S"""
  Allows opting out of using Permit for given controller actions.

  Defaults to `[]`, thus by default all actions are guarded with Permit.
  """
  @callback except() :: list(Types.action_group())

  @doc ~S"""
  If `Permit.Ecto` is not used, it allows defining a loader function that loads a record or a list of records, depending on action type (singular or plural).

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
  """
  @callback id_param_name(Types.action_group(), PhoenixTypes.conn()) :: binary()

  @doc ~S"""
  Sets the name of the field that contains the resource's ID which should be looked for.

  Defaults to `:id`. If the record's ID (usually a primary key) is in a different field, then it should be changed accordingly.
  """
  @callback id_struct_field_name(Types.action_group(), PhoenixTypes.conn()) :: atom()

  @optional_callbacks [
                        if(:ok == Application.ensure_loaded(:permit_ecto),
                          do: {:base_query, 1}
                        ),
                        if(:ok == Application.ensure_loaded(:permit_ecto),
                          do: {:finalize_query, 2}
                        ),
                        handle_unauthorized: 2,
                        preload_actions: 0,
                        fallback_path: 2,
                        resource_module: 0,
                        except: 0,
                        fetch_subject: 1,
                        loader: 1
                      ]
                      |> Enum.filter(& &1)

  defmacro __using__(opts) do
    quote generated: true do
      require Logger

      @behaviour unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      @on_definition {unquote(__MODULE__), :__on_definition__}
      @controller_actions []
      @opts unquote(opts)

      @impl true
      def handle_unauthorized(action, conn) do
        unquote(__MODULE__).handle_unauthorized(action, conn, unquote(opts))
      end

      @impl true
      def authorization_module,
        do:
          unquote(opts[:authorization_module]) ||
            raise(":authorization_module option must be given when using ControllerAuthorization")

      @impl true
      def resource_module, do: unquote(opts[:resource_module])

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

      if :ok == Application.ensure_loaded(:permit_ecto) do
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

      defoverridable(
        [
          if(:ok == Application.ensure_loaded(:permit_ecto),
            do: {:base_query, 1}
          ),
          if(:ok == Application.ensure_loaded(:permit_ecto),
            do: {:finalize_query, 2}
          ),
          handle_unauthorized: 2,
          preload_actions: 0,
          fallback_path: 2,
          resource_module: 0,
          except: 0,
          fetch_subject: 1,
          id_param_name: 2,
          id_struct_field_name: 2
        ]
        |> Enum.filter(& &1)
      )

      plug(:permit_phoenix_plug)
    end
  end

  def __on_definition__(env, _kind, name, _args, _guards, _body) do
    resource_module = Module.get_attribute(env.module, :resource_module)
    controller_actions = Module.get_attribute(env.module, :controller_actions)

    Module.put_attribute(env.module, :controller_actions, [
      {name, resource_module} | controller_actions
    ])

    Module.delete_attribute(env.module, :resource_module)
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

      def permit_phoenix_plug(conn, _opts) do
        Permit.Phoenix.Plug.call(
          conn,
          [
            if(:ok == Application.ensure_loaded(:permit_ecto),
              do: {:base_query, &__MODULE__.base_query/1}
            ),
            if(:ok == Application.ensure_loaded(:permit_ecto),
              do: {:finalize_query, &__MODULE__.finalize_query/2}
            ),
            if(:ok == Application.ensure_loaded(:permit_ecto),
              do: {:use_loader?, @loader_defined?}
            ),
            authorization_module: &__MODULE__.authorization_module/0,
            resource_module: &__MODULE__.resource_module/0,
            preload_actions: &__MODULE__.preload_actions/0,
            fallback_path: &__MODULE__.fallback_path/2,
            except: &__MODULE__.except/0,
            fetch_subject: &__MODULE__.fetch_subject/1,
            handle_unauthorized: &__MODULE__.handle_unauthorized/2,
            loader: &__MODULE__.loader/1,
            id_param_name: &__MODULE__.id_param_name/2,
            id_struct_field_name: &__MODULE__.id_struct_field_name/2,
            controller_actions: @controller_actions,
            id_struct_field_name: &__MODULE__.id_struct_field_name/2
          ]
          |> Enum.filter(& &1)
        )
      end
    end
  end

  @doc false
  def handle_unauthorized(action, conn, opts) do
    conn
    |> put_flash(
      :error,
      opts[:error_msg] || "You do not have permission to perform this action."
    )
    |> redirect(to: __MODULE__.fallback_path(action, conn, opts))
    |> halt()
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

  if :ok == Application.ensure_loaded(:permit_ecto) do
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
  def fetch_subject(conn, opts) do
    fetch_subject_fn = opts[:fetch_subject_fn]

    if is_function(fetch_subject_fn, 1) do
      fetch_subject_fn.(conn)
    else
      conn.assigns[:current_user]
    end
  end
end
