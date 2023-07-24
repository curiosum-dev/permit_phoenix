defmodule Permit.Phoenix.LiveView do
  @moduledoc """
  A live view module using the authorization mechanism should mix in the LiveViewAuthorization
  module:

      defmodule MyAppWeb.DocumentLive.Index
        use Permit.Phoenix.LiveView
      end

  which adds the LiveViewAuthorization behavior with the following callbacks to be implemented -
  for example:

      # The related schema

      @impl true
      def resource_module, do: Document

      # Loader function for a singular resource in appropriate actions (:show, etc.); usually a context
      # function. If not defined, Repo.get is used by default.

      @impl true
      def loader, do: fn id -> get_organization!(id) end

      # How to fetch the current user from session - for instance:

      @impl true
      def fetch_subject(socket, session) do
        with token when not is_nil(token) <- session["token"],
             %User{} = current_user <- get_user(token) do
          current_user
        else
          _ -> nil
        end
      end

  Optionally, p handle_unauthorized/2 optional callback can be implemented, returning {:cont, socket}
  or {:halt, socket}. The default implementation returns:

      {:halt, socket(socket, to: socket.view.fallback_path())}
  """
  alias Permit.Types
  alias Permit.Phoenix.Types, as: PhoenixTypes

  @callback resource_module() :: module()
  with {:module, Permit.Ecto} <- Code.ensure_compiled(Permit.Ecto) do
    @callback base_query(Types.resolution_context()) :: Ecto.Query.t()
    @callback finalize_query(Ecto.Query.t(), Types.resolution_context()) :: Ecto.Query.t()
  end

  @callback handle_unauthorized(Types.action_group(), PhoenixTypes.socket()) ::
              PhoenixTypes.hook_outcome()
  @callback fetch_subject(PhoenixTypes.socket(), map()) :: Types.subject()
  @callback authorization_module() :: Types.authorization_module()
  @callback preload_actions() :: list(Types.action_group())
  @callback fallback_path(Types.action_group(), PhoenixTypes.socket()) :: binary()
  @callback except() :: list(Types.action_group())
  @callback loader(Types.resolution_context()) :: Types.object() | nil

  @callback id_param_name(Types.action_group(), PhoenixTypes.socket()) :: binary()
  @callback id_struct_field_name(Types.action_group(), PhoenixTypes.socket()) :: atom()

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
                        loader: 1,
                        id_param_name: 2,
                        id_struct_field_name: 2
                      ]
                      |> Enum.filter(& &1)

  defmacro __using__(opts) do
    authorization_module =
      opts[:authorization_module] ||
        raise(":authorization_module option must be given when using LiveViewAuthorization")

    resource_module = opts[:resource_module]
    preload_actions = opts[:preload_actions]
    fallback_path = opts[:fallback_path]
    except = opts[:except]
    handle_unauthorized = opts[:handle_unauthorized]
    loader = opts[:loader]

    opts_id_param_name = opts[:id_param_name]
    opts_id_struct_field_name = opts[:id_struct_field_name]

    quote generated: true do
      import unquote(__MODULE__)

      with {:module, Permit.Ecto} <- Code.ensure_compiled(Permit.Ecto) do
        require Ecto.Query
      end

      @behaviour unquote(__MODULE__)

      @impl true
      def handle_unauthorized(action, socket) do
        handle_unauthorized = unquote(handle_unauthorized)

        case handle_unauthorized do
          nil -> {:halt, push_redirect(socket, to: fallback_path(action, socket))}
          fun when is_function(fun) -> fun.(action, socket)
          _ -> handle_unauthorized
        end
      end

      @impl true
      def authorization_module, do: unquote(authorization_module)

      @impl true
      def resource_module, do: unquote(resource_module)

      @impl true
      def preload_actions, do: (unquote(preload_actions) || []) ++ [:show, :edit, :index]

      @impl true
      def fallback_path(action, socket) do
        fallback_path = unquote(fallback_path)

        case fallback_path do
          nil -> "/"
          fun when is_function(fun) -> fun.(action, socket)
          _ -> fallback_path
        end
      end

      @impl true
      def except, do: unquote(except) || []

      if {:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto) do
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
        def finalize_query(query, %{}),
          do: query
      end

      @impl true
      def loader(resolution_context) do
        case unquote(loader) do
          nil -> nil
          function -> function.(resolution_context)
        end
      end

      @impl true
      def id_param_name(action, socket) do
        case unquote(opts_id_param_name) do
          nil -> "id"
          param_name when is_binary(param_name) -> param_name
          param_name_fn when is_function(param_name_fn) -> param_name_fn.(action, socket)
        end
      end

      @impl true
      def id_struct_field_name(action, socket) do
        case unquote(opts_id_struct_field_name) do
          nil ->
            :id

          struct_field_name when is_binary(struct_field_name) ->
            struct_field_name

          struct_field_name_fn when is_function(struct_field_name_fn) ->
            struct_field_name_fn.(action, socket)
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
          loader: 1,
          id_param_name: 2,
          id_struct_field_name: 2
        ]
        |> Enum.filter(& &1)
      )
    end
  end

  @doc """
  Returns true if inside mount/1, false otherwise. Useful for distinguishing between
  rendering directly via router or being in a handle_params lifecycle.

  For example, a handle_unauthorized/1 implementation must redirect when halting during mounting,
  while it needn't redirect when halting during the handle_params lifecycle.



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
    try do
      Phoenix.LiveView.get_connect_info(socket, :uri)
      true
    rescue
      # Raises RuntimeError if outside mount/1 because socket_info only exists while mounting.
      # This allows us to distinguish between accessing directly from router or via e.g. handle_params.
      RuntimeError -> false
    end
  end
end
