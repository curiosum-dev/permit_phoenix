if Version.match?(System.version(), ">= 1.15.0") and Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PermitPhoenix.Install do
    @shortdoc "Installs Permit.Phoenix authorization into your project"

    @moduledoc """
    Installs Permit.Phoenix authorization into your project, creating an actions module
    and patching the web module to include LiveView authorization.

    ## Usage

        mix permit_phoenix.install

    ## Options

    - `--authorization-module` - Authorization module name (default: `<MyApp>.Authorization`)
    - `--actions-module` - Actions module name (default: `<MyApp>.Authorization.Actions`)
    - `--router` - Phoenix router module (auto-detected if not specified)
    """

    use Igniter.Mix.Task

    alias Igniter.Code.Common
    alias Igniter.Code.Function
    alias Igniter.Libs.Phoenix, as: IgniterPhoenix
    alias Igniter.Project.Module, as: ProjectModule

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :permit,
        schema: [
          authorization_module: :string,
          actions_module: :string,
          router: :string
        ]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      options = igniter.args.options
      app_module = ProjectModule.module_name_prefix(igniter)
      web_module = IgniterPhoenix.web_module(igniter)

      authorization_module =
        parse_module(options[:authorization_module], Module.concat(app_module, Authorization))

      actions_module =
        parse_module(options[:actions_module], Module.concat(authorization_module, Actions))

      router = detect_router(igniter, options[:router], web_module)

      igniter
      |> create_actions_module(actions_module, router)
      |> patch_web_module_live_view(web_module, authorization_module)
      |> Igniter.add_notice("""
      Permit.Phoenix has been set up!

      Next steps:

        1. Add `Permit.Phoenix.LiveView.AuthorizeHook` to your router's live_session:

             live_session :authenticated,
               on_mount: [
                 {#{inspect(web_module)}.UserAuth, :ensure_authenticated},
                 Permit.Phoenix.LiveView.AuthorizeHook
               ] do
               # your live routes
             end

        2. In each LiveView, implement the `resource_module/0` callback:

             @impl true
             def resource_module, do: MyApp.MyResource

        3. For controllers, add to individual controllers:

             use Permit.Phoenix.Controller,
               authorization_module: #{inspect(authorization_module)},
               resource_module: MyApp.MyResource

           Or use `mix permit.patch.controller <ControllerModule> <ResourceModule>`.
      """)
    end

    defp create_actions_module(igniter, actions_module, router) do
      ProjectModule.create_module(igniter, actions_module, """
        use Permit.Phoenix.Actions, router: #{inspect(router)}
      """)
    end

    defp patch_web_module_live_view(igniter, web_module, authorization_module) do
      use_code =
        "use Permit.Phoenix.LiveView, authorization_module: #{inspect(authorization_module)}"

      case ProjectModule.find_and_update_module(igniter, web_module, fn zipper ->
             update_live_view_function(zipper, web_module, use_code)
           end) do
        {:ok, igniter} ->
          igniter

        {:error, igniter} ->
          Igniter.add_notice(igniter, """
          Could not find web module #{inspect(web_module)}.
          Please add the following to your web module's live_view/0 function's quote block:

              #{use_code}
          """)
      end
    end

    defp update_live_view_function(zipper, web_module, use_code) do
      case Function.move_to_def(zipper, :live_view, 0) do
        {:ok, live_view_zipper} ->
          inject_use_into_live_view(zipper, live_view_zipper, web_module, use_code)

        :error ->
          {:warning,
           """
           Could not find a `live_view/0` function in #{inspect(web_module)}.
           Please add the following to your web module's live_view/0 function:

               #{use_code}
           """}
      end
    end

    defp inject_use_into_live_view(zipper, live_view_zipper, web_module, use_code) do
      case find_use_call(live_view_zipper, Permit.Phoenix.LiveView) do
        {:ok, _} ->
          {:ok, zipper}

        :error ->
          case find_use_call(live_view_zipper, Phoenix.LiveView) do
            {:ok, use_zipper} ->
              {:ok, Common.add_code(use_zipper, use_code, placement: :after)}

            :error ->
              {:warning,
               """
               Could not find `use Phoenix.LiveView` in #{inspect(web_module)}'s live_view/0 function.
               Please add the following manually to your live_view/0 function's quote block:

                   #{use_code}
               """}
          end
      end
    end

    defp find_use_call(zipper, module) do
      Common.move_to(zipper, fn z ->
        Function.function_call?(z, :use, [1, 2]) &&
          Function.argument_matches_predicate?(
            z,
            0,
            &Common.nodes_equal?(&1, module)
          )
      end)
    end

    defp detect_router(_igniter, router_string, _web_module) when is_binary(router_string) do
      parse_module(router_string, nil)
    end

    defp detect_router(_igniter, nil, web_module) do
      Module.concat(web_module, Router)
    end

    defp parse_module(nil, default), do: default

    defp parse_module(string, _default) when is_binary(string) do
      string
      |> String.split(".")
      |> Module.concat()
    end
  end
end
