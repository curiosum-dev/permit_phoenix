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
  # alias Permit.FakeApp.Item.Context

  @callback authorization_module() :: module()
  @callback resource_module() :: module()

  with {:module, Permit.Ecto} <- Code.ensure_compiled(Permit.Ecto) do
    @callback prefilter_query_fn(Types.controller_action(), module(), map()) :: Ecto.Query.t()
    @callback postfilter_query_fn(Ecto.Query.t()) :: Ecto.Query.t()
  end

  @callback handle_unauthorized(Types.conn()) :: Types.conn()
  @callback user_from_conn(Types.conn()) :: struct()
  @callback preload_resource_in() :: list(atom())
  @callback fallback_path() :: binary()
  @callback except() :: list(atom())
  @callback loader_fn(Types.controller_action(), Types.resource_module(), Types.subject(), map()) ::
              any()
  @optional_callbacks [
                        if({:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto),
                          do: {:prefilter_query_fn, 3}
                        ),
                        if({:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto),
                          do: {:postfilter_query_fn, 1}
                        ),
                        handle_unauthorized: 1,
                        preload_resource_in: 0,
                        fallback_path: 0,
                        resource_module: 0,
                        except: 0,
                        user_from_conn: 1,
                        loader_fn: 4
                      ]
                      |> Enum.filter(& &1)

  defmacro __using__(opts) do
    opts_authorization_module =
      opts[:authorization_module] ||
        raise(":authorization_module option must be given when using ControllerAuthorization")

    opts_resource_module = opts[:resource_module]
    opts_preload_resource_in = opts[:preload_resource_in]
    opts_fallback_path = opts[:fallback_path]
    opts_except = opts[:except]
    loader_fn = opts[:loader_fn]

    # TODO: if prefilter_query_fn or postfilter_query_fn is defined alongside loader_fn, it should
    #       throw an error

    opts_id_param_name =
      Keyword.get(
        opts,
        :id_param_name,
        "id"
      )

    opts_id_struct_field_name =
      Keyword.get(
        opts,
        :id_struct_name,
        :id
      )

    opts_user_from_conn_fn = opts[:user_from_conn]

    quote generated: true do
      require Logger

      with {:module, Permit.Ecto} <- Code.ensure_compiled(Permit.Ecto) do
        require Ecto.Query
      end

      @behaviour unquote(__MODULE__)

      @impl true
      def handle_unauthorized(conn) do
        conn
        |> put_flash(
          :error,
          unquote(opts[:error_msg]) || "You do not have permission to perform this action."
        )
        |> redirect(to: __MODULE__.fallback_path())
        |> halt()
      end

      @impl true
      def authorization_module, do: unquote(opts_authorization_module)

      @impl true
      def resource_module, do: unquote(opts_resource_module)

      @impl true
      def preload_resource_in do
        preload_resource_in = unquote(opts_preload_resource_in)

        case preload_resource_in do
          nil -> [:show, :edit, :update, :delete]
          list when is_list(list) -> list ++ [:show, :edit, :update, :delete]
        end
      end

      @impl true
      def fallback_path do
        fallback_path = unquote(opts_fallback_path)

        case fallback_path do
          nil -> "/"
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
        def prefilter_query_fn(_action, resource_module, %{unquote(opts_id_param_name) => id}) do
          resource_module
          |> Permit.Ecto.filter_by_field(unquote(opts_id_struct_field_name), id)
        end

        def prefilter_query_fn(_action, resource_module, _params),
          do: Permit.Ecto.from(resource_module)

        @impl true
        def postfilter_query_fn(query), do: query
      end

      @impl true
      def user_from_conn(conn) do
        user_from_conn_fn = unquote(opts_user_from_conn_fn)

        cond do
          is_function(user_from_conn_fn, 1) ->
            user_from_conn_fn.(conn)

          true ->
            conn.assigns[:current_user]
        end
      end

      defoverridable(
        [
          if({:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto),
            do: {:prefilter_query_fn, 3}
          ),
          if({:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto),
            do: {:postfilter_query_fn, 1}
          ),
          handle_unauthorized: 1,
          preload_resource_in: 0,
          fallback_path: 0,
          resource_module: 0,
          except: 0,
          user_from_conn: 1
        ]
        |> Enum.filter(& &1)
      )

      plug(
        Permit.Phoenix.Plug,
        [
          if({:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto),
            do: {:prefilter_query_fn, &__MODULE__.prefilter_query_fn/3}
          ),
          if({:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto),
            do: {:postfilter_query_fn, &__MODULE__.postfilter_query_fn/1}
          ),
          authorization_module: &__MODULE__.authorization_module/0,
          resource_module: &__MODULE__.resource_module/0,
          preload_resource_in: &__MODULE__.preload_resource_in/0,
          fallback_path: &__MODULE__.fallback_path/0,
          except: &__MODULE__.except/0,
          user_from_conn: &__MODULE__.user_from_conn/1,
          handle_unauthorized: &__MODULE__.handle_unauthorized/1,
          loader_fn: unquote(loader_fn)
        ]
        |> Enum.filter(& &1)
      )
    end
  end
end
