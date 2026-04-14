if Version.match?(System.version(), ">= 1.15.0") and Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Permit.Patch.Controller do
    @shortdoc "Patches a Phoenix controller to use Permit authorization"

    @moduledoc """
    Patches an existing Phoenix controller to use Permit authorization.

    Adds `use Permit.Phoenix.Controller` with the specified `authorization_module`
    and `resource_module`. If the controller already has `use Permit.Phoenix.Controller`
    but no `resource_module`, adds a `resource_module/0` callback before the first
    function definition.

    ## Usage

        mix permit.patch.controller MyAppWeb.ItemController MyApp.Item

    ## Arguments

    - `controller_name` (required) - The controller module to patch
    - `resource_module` (required) - The Ecto schema or resource module

    ## Options

    - `--authorization-module` - Authorization module name (default: `<MyApp>.Authorization`)
    """

    use Igniter.Mix.Task

    alias Igniter.Code.Common
    alias Igniter.Code.Function
    alias Igniter.Code.Keyword, as: CodeKeyword
    alias Igniter.Code.Module, as: CodeModule
    alias Igniter.Project.Module, as: ProjectModule

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :permit,
        positional: [:controller_name, :resource_module],
        schema: [
          authorization_module: :string
        ]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      options = igniter.args.options
      positional = igniter.args.positional
      app_module = ProjectModule.module_name_prefix(igniter)

      controller_module = parse_module!(positional[:controller_name], "controller_name")
      resource_module = parse_module!(positional[:resource_module], "resource_module")

      authorization_module =
        parse_module(options[:authorization_module], Module.concat(app_module, Authorization))

      use_code = """
      use Permit.Phoenix.Controller,
        authorization_module: #{inspect(authorization_module)},
        resource_module: #{inspect(resource_module)}
      """

      case ProjectModule.find_and_update_module(igniter, controller_module, fn zipper ->
             update_controller(zipper, resource_module, use_code)
           end) do
        {:ok, igniter} ->
          Igniter.add_notice(igniter, controller_notice(controller_module, authorization_module, resource_module))

        {:error, igniter} ->
          Igniter.add_issue(igniter, """
          Could not find module #{inspect(controller_module)}.
          Make sure the module exists and the name is correct.
          """)
      end
    end

    defp controller_notice(controller_module, authorization_module, resource_module) do
      """
      Patched #{inspect(controller_module)} with Permit authorization.

      The controller now uses:
        * authorization_module: #{inspect(authorization_module)}
        * resource_module: #{inspect(resource_module)}

      Next steps:

        1. In each action, replace manual record lookups with `conn.assigns.loaded_resource`
           (singular actions like `show`, `edit`, `update`, `delete`) or
           `conn.assigns.loaded_resources` (plural actions like `index`).

        2. Ensure your permissions module (#{inspect(authorization_module)}.Permissions) defines
           rules for the relevant actions on #{inspect(resource_module)}.
      """
    end

    defp update_controller(zipper, resource_module, use_code) do
      case CodeModule.move_to_use(zipper, Permit.Phoenix.Controller) do
        {:ok, _zipper} ->
          add_resource_module_callback(zipper, resource_module)

        _ ->
          add_use_permit_controller(zipper, use_code)
      end
    end

    defp add_use_permit_controller(zipper, use_code) do
      case find_last_use(zipper) do
        {:ok, zipper} ->
          {:ok, Common.add_code(zipper, use_code, placement: :after)}

        :error ->
          {:ok, Common.add_code(zipper, use_code, placement: :before)}
      end
    end

    defp add_resource_module_callback(zipper, resource_module) do
      has_def? = match?({:ok, _}, Function.move_to_def(zipper, :resource_module, 0))

      if has_def? or has_resource_module_in_use?(zipper) do
        {:ok, zipper}
      else
        callback_code = """
        @impl true
        def resource_module, do: #{inspect(resource_module)}
        """

        insert_before_first_def(zipper, callback_code)
      end
    end

    defp has_resource_module_in_use?(zipper) do
      case CodeModule.move_to_use(zipper, Permit.Phoenix.Controller) do
        {:ok, use_zipper} ->
          Function.argument_matches_predicate?(use_zipper, 1, fn opts_zipper ->
            CodeKeyword.keyword_has_path?(opts_zipper, [:resource_module])
          end)

        _ ->
          false
      end
    end

    defp insert_before_first_def(zipper, code) do
      case Function.move_to_def(zipper, target: :before) do
        {:ok, def_zipper} ->
          {:ok, Common.add_code(def_zipper, code, placement: :before)}

        :error ->
          case find_last_use(zipper) do
            {:ok, use_zipper} ->
              {:ok, Common.add_code(use_zipper, code, placement: :after)}

            :error ->
              {:ok, Common.add_code(zipper, code, placement: :before)}
          end
      end
    end

    defp find_last_use(zipper) do
      find_last_use(zipper, :error)
    end

    defp find_last_use(zipper, last_match) do
      case Common.move_to(zipper, fn z ->
             Function.function_call?(z, :use, [1, 2])
           end) do
        {:ok, found} ->
          case Sourceror.Zipper.right(found) do
            nil -> {:ok, found}
            next -> find_last_use(next, {:ok, found})
          end

        :error ->
          last_match
      end
    end

    defp parse_module!(nil, arg_name) do
      Mix.raise("Missing required argument: #{arg_name}")
    end

    defp parse_module!(string, _arg_name) when is_binary(string) do
      string |> String.split(".") |> Module.concat()
    end

    defp parse_module(nil, default), do: default

    defp parse_module(string, _default) when is_binary(string) do
      string |> String.split(".") |> Module.concat()
    end
  end
end
