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
  alias Permit.Types
  alias Permit.Phoenix.Types, as: PhoenixTypes

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

  with {:module, Permit.Ecto} <- Code.ensure_compiled(Permit.Ecto) do
    @doc ~S"""
    Creates the basis for an Ecto query constructed by `Permit.Ecto` based on controller action, resource module, subject (typically `:current_user`) and controller params.

    Typically useful when using [nested resource routes](https://hexdocs.pm/phoenix/routing.html#nested-resources). In an action routed like `/users/:user_id/posts/:id`, you can use the `c:base_query/1` callback to filter records by `user_id`, while filtering by `id` itself will be applied automatically (the name of the ID parameter can be overridden with the `c:id_`).


    """
    @callback base_query(Types.resolution_context()) :: Ecto.Query.t()
    @callback finalize_query(Ecto.Query.t(), Types.resolution_context()) :: Ecto.Query.t()
  end

  @callback handle_unauthorized(Types.action_group(), PhoenixTypes.conn()) :: PhoenixTypes.conn()
  @callback fetch_subject(PhoenixTypes.conn()) :: Types.subject()
  @callback preload_actions() :: list(Types.action_group())
  @callback fallback_path(Types.action_group(), PhoenixTypes.conn()) :: binary()
  @callback except() :: list(Types.action_group())
  @callback loader(Types.resolution_context()) :: Types.object() | nil

  @callback id_param_name(Types.action_group(), PhoenixTypes.conn()) :: binary()
  @callback id_struct_field_name(Types.action_group(), PhoenixTypes.conn()) :: atom()

  @optional_callbacks [
                        if({:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto),
                          do: {:base_query, 1}
                        ),
                        if({:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto),
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
    opts_authorization_module =
      opts[:authorization_module] ||
        raise(":authorization_module option must be given when using ControllerAuthorization")

    opts_resource_module = opts[:resource_module]
    opts_preload_actions = opts[:preload_actions]
    opts_fallback_path = opts[:fallback_path]
    opts_except = opts[:except]
    loader = opts[:loader]

    opts_id_param_name = opts[:id_param_name]
    opts_id_struct_field_name = opts[:id_struct_field_name]

    opts_fetch_subject_fn = opts[:fetch_subject]

    quote generated: true do
      require Logger

      with {:module, Permit.Ecto} <- Code.ensure_compiled(Permit.Ecto) do
        require Ecto.Query
      end

      @behaviour unquote(__MODULE__)

      @impl true
      def handle_unauthorized(action, conn) do
        conn
        |> put_flash(
          :error,
          unquote(opts[:error_msg]) || "You do not have permission to perform this action."
        )
        |> redirect(to: __MODULE__.fallback_path(action, conn))
        |> halt()
      end

      @impl true
      def authorization_module, do: unquote(opts_authorization_module)

      @impl true
      def resource_module, do: unquote(opts_resource_module)

      @impl true
      def preload_actions do
        preload_actions = unquote(opts_preload_actions)

        case preload_actions do
          nil -> [:show, :edit, :update, :delete, :index]
          list when is_list(list) -> list ++ [:show, :edit, :update, :delete, :index]
        end
      end

      @impl true
      def fallback_path(action, conn) do
        fallback_path = unquote(opts_fallback_path)

        case fallback_path do
          nil -> "/"
          fun when is_function(fun) -> fun.(action, conn)
          _ -> fallback_path
        end
      end

      @impl true
      def except do
        except = unquote(opts_except)

        case except do
          nil -> []
          _ -> except
        end
      end

      with {:module, Permit.Ecto} <- Code.ensure_compiled(Permit.Ecto) do
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
        def finalize_query(query, %{}), do: query
      end

      @impl true
      def loader(resolution_context) do
        case unquote(loader) do
          nil -> nil
          function -> function.(resolution_context)
        end
      end

      @impl true
      def id_param_name(action, conn) do
        case unquote(opts_id_param_name) do
          nil -> "id"
          param_name when is_binary(param_name) -> param_name
          param_name_fn when is_function(param_name_fn) -> param_name_fn.(action, conn)
        end
      end

      @impl true
      def id_struct_field_name(action, conn) do
        case unquote(opts_id_struct_field_name) do
          nil ->
            :id

          struct_field_name when is_binary(struct_field_name) ->
            struct_field_name

          struct_field_name_fn when is_function(struct_field_name_fn) ->
            struct_field_name_fn.(action, conn)
        end
      end

      @impl true
      def fetch_subject(conn) do
        fetch_subject_fn = unquote(opts_fetch_subject_fn)

        cond do
          is_function(fetch_subject_fn, 1) ->
            fetch_subject_fn.(conn)

          true ->
            conn.assigns[:current_user]
        end
      end

      defoverridable(
        [
          if({:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto),
            do: {:base_query, 1}
          ),
          if({:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto),
            do: {:finalize_query, 2}
          ),
          handle_unauthorized: 2,
          preload_actions: 0,
          fallback_path: 2,
          resource_module: 0,
          except: 0,
          fetch_subject: 1,
          loader: 1,
          id_param_name: 2,
          id_struct_field_name: 2
        ]
        |> Enum.filter(& &1)
      )

      plug(
        Permit.Phoenix.Plug,
        [
          if({:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto),
            do: {:base_query, &__MODULE__.base_query/1}
          ),
          if({:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto),
            do: {:finalize_query, &__MODULE__.finalize_query/2}
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
          id_struct_field_name: &__MODULE__.id_struct_field_name/2
        ]
        |> Enum.filter(& &1)
      )
    end
  end
end
