defmodule Permit.Phoenix.Plug do
  @moduledoc false

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
      |> Keyword.merge(build_opts_from_controller(conn))
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

  @permit_ecto_available? Permit.Phoenix.Utils.permit_ecto_available?()

  defp build_opts_from_controller(conn) do
    controller_module = Phoenix.Controller.controller_module(conn)

    # Check if the controller implements Permit.Phoenix.Controller behavior
    if function_exported?(controller_module, :authorization_module, 0) do
      # Check if a custom loader is defined by calling the internal function
      # that the Controller module provides
      use_loader? =
        if function_exported?(controller_module, :__permit_loader_defined__?, 0) do
          controller_module.__permit_loader_defined__?()
        else
          false
        end

      [
        if(@permit_ecto_available?,
          do: {:base_query, &controller_module.base_query/1}
        ),
        if(@permit_ecto_available?,
          do: {:finalize_query, &controller_module.finalize_query/2}
        ),
        if(@permit_ecto_available?,
          do: {:use_loader?, use_loader?}
        ),
        authorization_module: &controller_module.authorization_module/0,
        resource_module: &controller_module.resource_module/0,
        skip_preload: &controller_module.skip_preload/0,
        fallback_path: &controller_module.fallback_path/2,
        except: &controller_module.except/0,
        fetch_subject: &controller_module.fetch_subject/1,
        handle_unauthorized: &controller_module.handle_unauthorized/2,
        loader: &controller_module.loader/1,
        id_param_name: &controller_module.id_param_name/2,
        id_struct_field_name: &controller_module.id_struct_field_name/2,
        handle_not_found: &controller_module.handle_not_found/1,
        unauthorized_message: &controller_module.unauthorized_message/2
      ]
      |> Enum.filter(& &1)
    else
      raise "Permit.Phoenix.Plug must not be used directly. Use this instead: \n" <>
              "use Permit.Phoenix.Controller, opts"
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
    if action_group in opts[:skip_preload] do
      just_authorize(conn, opts, action_group, subject, resource_module)
    else
      authorize_and_preload_resource(conn, opts, action_group, subject, resource_module)
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
