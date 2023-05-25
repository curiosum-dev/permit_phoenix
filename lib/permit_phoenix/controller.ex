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
    @callback base_query(Types.controller_action(), module(), Types.subject(), map()) ::
                Ecto.Query.t()
    @callback finalize_query(
                Ecto.Query.t(),
                Types.controller_action(),
                module(),
                Types.subject(),
                map()
              ) :: Ecto.Query.t()
  end

  @callback handle_unauthorized(Types.conn()) :: Types.conn()
  @callback fetch_subject(Types.conn()) :: struct()
  @callback preload_actions() :: list(atom())
  @callback fallback_path() :: binary()
  @callback except() :: list(atom())
  @callback loader(Types.controller_action(), Types.resource_module(), Types.subject(), map()) ::
              any()
  @optional_callbacks [
                        if({:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto),
                          do: {:base_query, 4}
                        ),
                        if({:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto),
                          do: {:finalize_query, 5}
                        ),
                        handle_unauthorized: 1,
                        preload_actions: 0,
                        fallback_path: 0,
                        resource_module: 0,
                        except: 0,
                        fetch_subject: 1,
                        loader: 4
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

    opts_fetch_subject_fn = opts[:fetch_subject]

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
      def preload_actions do
        preload_actions = unquote(opts_preload_actions)

        case preload_actions do
          nil -> [:show, :edit, :update, :delete, :index]
          list when is_list(list) -> list ++ [:show, :edit, :update, :delete, :index]
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
        def base_query(_action, resource_module, _subject, %{unquote(opts_id_param_name) => id}) do
          resource_module
          |> Permit.Ecto.filter_by_field(unquote(opts_id_struct_field_name), id)
        end

        def base_query(_action, resource_module, _subject, _params),
          do: Permit.Ecto.from(resource_module)

        @impl true
        def finalize_query(query, _action, _resource_module, _subject, _params), do: query
      end

      @impl true
      def loader(action, resource_module, subject, params) do
        case unquote(loader) do
          nil -> nil
          function -> function.(action, resource_module, subject, params)
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
            do: {:base_query, 4}
          ),
          if({:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto),
            do: {:finalize_query, 5}
          ),
          handle_unauthorized: 1,
          preload_actions: 0,
          fallback_path: 0,
          resource_module: 0,
          except: 0,
          fetch_subject: 1,
          loader: 4
        ]
        |> Enum.filter(& &1)
      )

      plug(
        Permit.Phoenix.Plug,
        [
          if({:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto),
            do: {:base_query, &__MODULE__.base_query/4}
          ),
          if({:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto),
            do: {:finalize_query, &__MODULE__.finalize_query/5}
          ),
          authorization_module: &__MODULE__.authorization_module/0,
          resource_module: &__MODULE__.resource_module/0,
          preload_actions: &__MODULE__.preload_actions/0,
          fallback_path: &__MODULE__.fallback_path/0,
          except: &__MODULE__.except/0,
          fetch_subject: &__MODULE__.fetch_subject/1,
          handle_unauthorized: &__MODULE__.handle_unauthorized/1,
          loader: &__MODULE__.loader/4
        ]
        |> Enum.filter(& &1)
      )
    end
  end
end
