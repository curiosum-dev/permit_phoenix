defmodule Permit.Phoenix.Types do
  @moduledoc """
  Defines types for usage with Permit in the context of Phoenix applications.
  """

  alias Permit.Types

  @permit_ecto_available? Permit.Phoenix.Utils.permit_ecto_available?()

  # Phoenix-specific types
  @type conn :: Plug.Conn.t()

  # Phoenix LiveView-specific types
  @type socket :: Phoenix.LiveView.Socket.t()
  @type session :: map()
  @type hook_outcome :: {:halt, socket()} | {:cont, socket()} | no_return()
  @type live_authorization_result :: {:authorized | :unauthorized | :not_found, socket()}

  # Opts types
  @type action_list :: list(Types.action_group())

  @typedoc """
  A name of a resource struct's ID parameter in controller or LiveView params, typically represented by a string.
  """
  @type id_param_name :: binary()

  @typedoc """
  A default fallback path for the controller in case there's no authorization.
  """
  @type fallback_path :: binary()

  @typedoc """
  A default error message for the controller in case there's no authorization.
  """
  @type error_msg :: binary()

  @typedoc """
  A default handler that is called in case there is no authorization.
  """
  @type handle_unauthorized :: (Types.action_group(), conn() -> conn())

  @typedoc """
  Maps the current Phoenix scope to the subject.
  """
  @type scope_subject :: (map() -> Types.subject()) | atom()

  if @permit_ecto_available? do
    @typedoc """
    - `:authorization_module` -- (Required) The app's authorization module that uses `use Permit`.
    - `preload_actions` -- (Optional) The list of actions that resources will be preloaded and authorized in, in addition to :show, :delete, :edit and :update.
    - `loader` -- (Required, unless :repo defined) The loader, 1-arity function, used to fetch records in singular resource functions (:show, :edit, :update, :delete and other defined as :preload_actions). It is convenient to use context getter functions as loaders.
    - `resource` -- (Required) The struct module defining the specific resource the controller is dealing with.
    - `id_param_name` -- (Required, if singular record actions are present) The parameter name used to look for IDs of resources, passed to the loader function or the repo.
    - `fallback_path` -- (Optional) A string denoting redirect path when unauthorized. Defaults to "/".
    - `error_msg` -- (Optional) An error message to put into the flash when unauthorizd. Defaults to "You do not have permission to perform this action."
    - `handle_unauthorized - (Optional) A function taking (conn), performing specific action when authorization is not successful. Defaults to redirecting to :fallback_path.
    """

    @type plug_opts :: [
            authorization_module: Types.authorization_module(),
            base_query: Permit.Ecto.Types.base_query(),
            finalize_query: Permit.Ecto.Types.finalize_query(),
            resource_module: Types.resource_module(),
            preload_actions: action_list(),
            id_param_name: id_param_name(),
            except: action_list(),
            fallback_path: fallback_path(),
            error_msg: error_msg(),
            handle_unauthorized: handle_unauthorized()
          ]
  else
    @type plug_opts :: [
            authorization_module: Types.authorization_module(),
            resource_module: Types.resource_module(),
            preload_actions: action_list(),
            id_param_name: id_param_name(),
            except: action_list(),
            fallback_path: fallback_path(),
            error_msg: error_msg(),
            handle_unauthorized: handle_unauthorized(),
            loader: Types.loader()
          ]
  end
end
