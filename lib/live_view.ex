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
  alias Permit.Phoenix.Types, as: PhoenixTypes
  alias Permit.Types
  alias PermitPhoenix.RecordNotFoundError

  import Phoenix.LiveView

  @callback resource_module() :: module()

  if Mix.Dep.Lock.read()[:permit_ecto] do
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
  @callback handle_not_found(PhoenixTypes.socket()) :: PhoenixTypes.hook_outcome()
  @callback id_param_name(Types.action_group(), PhoenixTypes.socket()) :: binary()
  @callback id_struct_field_name(Types.action_group(), PhoenixTypes.socket()) :: atom()
  @callback unauthorized_message(PhoenixTypes.socket(), map()) :: binary()
  @callback event_mapping() :: map()

  @optional_callbacks [
                        if(Mix.Dep.Lock.read()[:permit_ecto],
                          do: {:base_query, 1}
                        ),
                        if(Mix.Dep.Lock.read()[:permit_ecto],
                          do: {:finalize_query, 2}
                        ),
                        handle_unauthorized: 2,
                        preload_actions: 0,
                        fallback_path: 2,
                        resource_module: 0,
                        except: 0,
                        loader: 1,
                        id_param_name: 2,
                        id_struct_field_name: 2,
                        handle_not_found: 1,
                        unauthorized_message: 2
                      ]
                      |> Enum.filter(& &1)

  defmacro __using__(opts) do
    quote generated: true do
      import unquote(__MODULE__)

      if Mix.Dep.Lock.read()[:permit_ecto] do
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

      if Mix.Dep.Lock.read()[:permit_ecto] do
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

      defoverridable(
        [
          if(Mix.Dep.Lock.read()[:permit_ecto],
            do: {:base_query, 1}
          ),
          if(Mix.Dep.Lock.read()[:permit_ecto],
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
          unauthorized_message: 2
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
         |> navigate(to: socket.view.fallback_path(action, socket))}

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
      nil -> "/"
      fun when is_function(fun) -> fun.(action, socket)
      path -> path
    end
  end

  if Mix.Dep.Lock.read()[:permit_ecto] do
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

  defp navigate(socket, arg) do
    if function_exported?(Phoenix.LiveView, :push_navigate, 2) do
      apply(Phoenix.LiveView, :push_navigate, [socket, arg])
    else
      apply(Phoenix.LiveView, :push_redirect, [socket, arg])
    end
  end
end
