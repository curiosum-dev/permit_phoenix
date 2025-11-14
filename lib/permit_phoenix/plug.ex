defmodule Permit.Phoenix.Plug do
  @moduledoc """
  Authorization plug for the web application.

  It automatically infers what CRUD action is represented by the currently executed controller
  action, and delegates to Permit to determine whether the action is authorized based
  on current user's role.

  Current user is always fetched from `conn.assigns[:current_user]`, and their role is taken
  from the module specified in the app's `use Permit` directive. For instance if it's
  configured as follows:

  ```
  # Authorization configuration module
  defmodule MyApp.Authorization do
    use Permit,
      repo: Lvauth.Repo,
      permissions_module: MyApp.Authorization.Permissions
  end

  # Permissions module - just as an example
  defmodule MyApp.Authorization.Permissions do
    use Permit.Permissions

    def can(%{role: :manager} = role) do
      # A :manager can do all CRUD actions on RouteTemplate, and can do :read on User
      # if the User has public: true OR the User has :overseer_id equal to current user's
      # id.
      permit()
      |> all(Lvauth.Planning.RouteTemplate)
      |> read(Lvauth.Accounts.User, public: true)
      |> read(LvMainFrame.Accounts.User,
              fn user, other_user -> other_user.overseer_id == user.id end)
    end
  end
  ```

  Then controller can be configured the following way:

  ```
  defmodule LvauthWeb.Planning.RouteTemplateController do
    plug Permit.Phoenix.Plug,
      authorization_module: MyApp.Authorization,
      loader: fn id -> Lvauth.Repo.get(Customer, id) end,
      resource_module: Lvauth.Management.Customer,
      id_param_name: "id",
      except: [:example],
      fetch_subject: fn conn -> conn.assigns[:signed_in_user] end
      handle_unauthorized: fn conn -> redirect(conn, to: "/foo") end

    def show(conn, params) do
      # 1. If assigns[:current_user] is present, the "id" param will be used to call
      #    Repo.get(Customer, params["id"]).
      # 2. can(role) |> read?(record) will be called on the loaded record and each user role.
      # 3. If authorization succeeds, the record will be stored in assigns[:loaded_resources].
      # 4. If any of the steps described above fails, the pipeline will be halted.
    end

    def index(conn, params) do
      # 1. If assigns[:current_user] is present, can(role) |> read?(Customer) will be called on each role
      # 2. If authorization succeeds, nothing happens.
      # 3. If any of the steps described above fails, the pipeline will be halted.
    end

    def details(conn, params) do
      # Behaves identically to :show because in :action_crud_mapping it's defined as :read.
    end

    def clone(conn, params) do
      # 1. If assigns[:current_user] is present, the "id" param will be used to call
      #    Repo.get(Customer, params["id"]).
      # 2. can(role) |> update?(record) will be called on the loaded record (as configured in :action_crud_mapping) and each role of user
      # 3. If authorization succeeds, the record will be stored in assigns[:loaded_resources].
      # 4. If any of the steps described above fails, the pipeline will be halted.
    end
  end
  ```

  ##
  """

  alias Permit.Phoenix.Types, as: PhoenixTypes
  alias Permit.{Resolver, Types}

  @spec init(PhoenixTypes.plug_opts()) :: PhoenixTypes.plug_opts()
  def init(opts) do
    opts
  end

  @spec call(PhoenixTypes.conn(), PhoenixTypes.plug_opts()) :: Plug.Conn.t()
  def call(conn, opts) do
    opts =
      opts
      |> Enum.map(fn
        {opt_name, opt_function} when is_function(opt_function, 0) ->
          {opt_name, opt_function.()}

        otherwise ->
          otherwise
      end)

    action_group = Phoenix.Controller.action_name(conn)

    if action_group in opts[:except] do
      conn
    else
      resource_module = opts[:resource_module]

      subject = opts[:fetch_subject].(conn)

      authorize(conn, opts, action_group, subject, resource_module)
    end
  end

  @spec authorize(
          PhoenixTypes.conn(),
          PhoenixTypes.plug_opts(),
          Types.action_group(),
          Types.subject() | nil,
          Types.object_or_resource_module()
        ) ::
          Plug.Conn.t()
  defp authorize(conn, opts, action, nil, _resource) do
    # subject is nil - meaning authorization is not granted
    opts[:handle_unauthorized].(action, conn)
  end

  defp authorize(conn, opts, action_group, subject, resource_module) do
    if action_group in opts[:preload_actions] do
      authorize_and_preload_resource(conn, opts, action_group, subject, resource_module)
    else
      just_authorize(conn, opts, action_group, subject, resource_module)
    end
  end

  @spec just_authorize(
          PhoenixTypes.conn(),
          PhoenixTypes.plug_opts(),
          Types.action_group(),
          Types.subject() | nil,
          Types.resource_module()
        ) ::
          Plug.Conn.t()
  defp just_authorize(conn, opts, action, subject, resource_module) do
    authorization_module = Keyword.fetch!(opts, :authorization_module)

    Resolver.authorized?(
      subject,
      authorization_module,
      resource_module,
      action
    )
    |> case do
      true -> conn
      false -> opts[:handle_unauthorized].(action, conn)
    end
  end

  @spec authorize_and_preload_resource(
          PhoenixTypes.conn(),
          PhoenixTypes.plug_opts(),
          Types.action_group(),
          Types.subject() | nil,
          Types.resource_module()
        ) ::
          Plug.Conn.t()
  defp authorize_and_preload_resource(conn, opts, action, subject, resource_module) do
    controller_module = Phoenix.Controller.controller_module(conn)

    authorization_module = Keyword.fetch!(opts, :authorization_module)

    # actions_module = authorization_module.actions_module()
    number = if action in controller_module.singular_actions(), do: :one, else: :all

    meta =
      %{
        loader: opts[:loader],
        base_query: opts[:base_query],
        finalize_query: opts[:finalize_query],
        params: conn.params,
        conn: conn,
        use_loader?: opts[:use_loader?]
      }
      |> Map.filter(fn {_, val} -> !!val end)

    load_key = if number == :one, do: :loaded_resource, else: :loaded_resources

    case authorize_and_preload_fn(number, authorization_module).(
           subject,
           authorization_module,
           resource_module,
           action,
           meta
         ) do
      {:authorized, record_or_records} -> Plug.Conn.assign(conn, load_key, record_or_records)
      :unauthorized -> opts[:handle_unauthorized].(action, conn)
      :not_found -> opts[:handle_not_found].(conn)
    end
  end

  defp authorize_and_preload_fn(number, authorization_module)

  defp authorize_and_preload_fn(:one, authorization_module) do
    module = authorization_module.resolver_module()
    &module.authorize_and_preload_one!/5
  end

  defp authorize_and_preload_fn(:all, authorization_module) do
    module = authorization_module.resolver_module()
    &module.authorize_and_preload_all!/5
  end
end
