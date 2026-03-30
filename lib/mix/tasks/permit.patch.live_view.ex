if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Permit.Patch.LiveView do
    @shortdoc "Patches a Phoenix LiveView to use Permit authorization"

    @moduledoc """
    Patches an existing Phoenix LiveView to use Permit authorization by adding
    a `resource_module/0` callback.

    ## Usage

        mix permit.patch.live_view MyAppWeb.NoteLive.Index MyApp.Note

    ## Arguments

    - `module_name` (required) - The LiveView module to patch
    - `resource_module` (required) - The Ecto schema or resource module

    ## Options

    - `--authorization-module` - Authorization module name (default: `<MyApp>.Authorization`)
    """

    use Igniter.Mix.Task

    alias Igniter.Code.Common
    alias Igniter.Code.Function
    alias Igniter.Code.Module, as: CodeModule
    alias Igniter.Project.Module, as: ProjectModule

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :permit,
        positional: [:module_name, :resource_module],
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

      live_view_module = parse_module!(positional[:module_name], "module_name")
      resource_module = parse_module!(positional[:resource_module], "resource_module")

      authorization_module =
        parse_module(options[:authorization_module], Module.concat(app_module, Authorization))

      case ProjectModule.find_and_update_module(igniter, live_view_module, fn zipper ->
             zipper
             |> maybe_add_use_permit_live_view(authorization_module)
             |> add_resource_module_callback(resource_module)
           end) do
        {:ok, igniter} ->
          Igniter.add_notice(igniter, """
          Patched #{inspect(live_view_module)} with Permit authorization.

          The LiveView now implements resource_module/0 returning #{inspect(resource_module)}.

          Ensure that:
            1. Permit.Phoenix.LiveView.AuthorizeHook is in the router's on_mount
            2. Add @permit_action before handle_event/3 clauses as needed
          """)

        {:error, igniter} ->
          Igniter.add_issue(igniter, """
          Could not find module #{inspect(live_view_module)}.
          Make sure the module exists and the name is correct.
          """)
      end
    end

    defp maybe_add_use_permit_live_view(zipper, authorization_module) do
      case CodeModule.move_to_use(zipper, Permit.Phoenix.LiveView) do
        {:ok, _} ->
          # Already present (directly or via web module)
          zipper

        _ ->
          use_code =
            "use Permit.Phoenix.LiveView, authorization_module: #{inspect(authorization_module)}"

          case find_last_use(zipper) do
            {:ok, use_zipper} ->
              Common.add_code(use_zipper, use_code, placement: :after)

            :error ->
              Common.add_code(zipper, use_code, placement: :before)
          end
      end
    end

    defp add_resource_module_callback(zipper, resource_module) do
      callback_code = """
      @impl true
      def resource_module, do: #{inspect(resource_module)}
      """

      case Function.move_to_def(zipper, :resource_module, 0) do
        {:ok, _zipper} ->
          {:ok, zipper}

        :error ->
          case find_last_use(zipper) do
            {:ok, use_zipper} ->
              {:ok, Common.add_code(use_zipper, callback_code, placement: :after)}

            :error ->
              {:ok, Common.add_code(zipper, callback_code, placement: :before)}
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
else
  defmodule Mix.Tasks.Permit.Patch.LiveView do
    @shortdoc "Patches a Phoenix LiveView to use Permit authorization"
    @moduledoc "Patches a LiveView to use Permit authorization. Requires the `igniter` package."

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The `permit.patch.live_view` task requires the `igniter` package.

      Please add `{:igniter, "~> 0.5"}` to your dependencies and run `mix deps.get`.
      """)
    end
  end
end
