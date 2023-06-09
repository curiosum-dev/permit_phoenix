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

  @callback handle_unauthorized(Types.socket()) :: Types.hook_outcome()
  @callback fetch_subject(map()) :: struct()
  @callback authorization_module() :: module()
  @callback preload_actions() :: list(atom())
  @callback fallback_path() :: binary()
  @callback except() :: list(atom())
  @callback loader(Types.controller_action(), Types.resource_module(), Types.subject(), map()) ::
              any()
  # TODO maybe filter those values and leave only load_fn
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
                        loader: 4
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

    quote generated: true do
      import unquote(__MODULE__)

      with {:module, Permit.Ecto} <- Code.ensure_compiled(Permit.Ecto) do
        require Ecto.Query
      end

      @behaviour unquote(__MODULE__)

      @impl true
      def handle_unauthorized(socket) do
        {:halt, push_redirect(socket, to: fallback_path())}
      end

      @impl true
      def authorization_module, do: unquote(authorization_module)

      @impl true
      def resource_module, do: unquote(resource_module)

      @impl true
      def preload_actions, do: (unquote(preload_actions) || []) ++ [:show, :edit, :index]

      @impl true
      def fallback_path, do: unquote(fallback_path) || "/"

      @impl true
      def except, do: unquote(except) || []

      if {:module, Permit.Ecto} == Code.ensure_compiled(Permit.Ecto) do
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
          loader: 4
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
  @spec mounting?(Types.socket()) :: boolean()
  def mounting?(socket) do
    try do
      Phoenix.LiveView.get_connect_info(socket, :uri)
      true
    rescue
      # Raises RuntimeError if outside mount/1 because connect_info only exists while mounting.
      # This allows us to distinguish between accessing directly from router or via e.g. handle_params.
      RuntimeError -> false
    end
  end
end
