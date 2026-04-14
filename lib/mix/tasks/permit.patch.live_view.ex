if Version.match?(System.version(), ">= 1.15.0") and Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Permit.Patch.LiveView do
    @shortdoc "Patches a Phoenix LiveView to use Permit authorization"

    @moduledoc """
    Patches an existing Phoenix LiveView to use Permit authorization by adding
    a `resource_module/0` callback and `@permit_action` annotations on `handle_event/3`
    clauses with recognized event names.

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

    @known_actions %{
      "delete" => :delete,
      "update" => :update,
      "create" => :create
    }

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
             |> annotate_handle_events()
           end) do
        {:ok, igniter} ->
          Igniter.add_notice(igniter, live_view_notice(live_view_module, resource_module))

        {:error, igniter} ->
          Igniter.add_issue(igniter, """
          Could not find module #{inspect(live_view_module)}.
          Make sure the module exists and the name is correct.
          """)
      end
    end

    defp live_view_notice(live_view_module, resource_module) do
      """
      Patched #{inspect(live_view_module)} with Permit authorization.

      The LiveView now implements resource_module/0 returning #{inspect(resource_module)}.
      Recognized `handle_event/3` clauses (delete/update/create) were annotated with `@permit_action`.

      Next steps:

        1. Ensure `Permit.Phoenix.LiveView.AuthorizeHook` is in the router's on_mount for
           this LiveView's live_session.

        2. Add `@permit_action` annotations to any remaining `handle_event/3` clauses as needed.

        3. Replace context-based record lookups with `socket.assigns.loaded_resource` /
           `socket.assigns.loaded_resources` (populated by Permit after authorization).
      """
    end

    # --- Use statement ---

    defp maybe_add_use_permit_live_view(zipper, authorization_module) do
      case CodeModule.move_to_use(zipper, Permit.Phoenix.LiveView) do
        {:ok, _} ->
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
          insert_before_first_def(zipper, callback_code)
      end
    end

    defp annotate_handle_events({:ok, zipper}), do: do_annotate_handle_events(zipper)

    defp do_annotate_handle_events(zipper) do
      case Function.move_to_def(zipper, :handle_event, 3, target: :at) do
        {:ok, event_zipper} ->
          event_name = extract_event_name(Sourceror.Zipper.node(event_zipper))

          case Map.get(@known_actions, event_name) do
            nil ->
              {:ok, zipper}

            action ->
              if already_annotated?(event_zipper, action) do
                {:ok, zipper}
              else
                {:ok,
                 Common.add_code(event_zipper, "@permit_action :#{action}", placement: :before)}
              end
          end

        :error ->
          {:ok, zipper}
      end
    end

    defp already_annotated?(event_zipper, action) do
      case Sourceror.Zipper.left(event_zipper) do
        nil ->
          false

        left_zipper ->
          match?(
            {:@, _, [{:permit_action, _, [{:__block__, _, [^action]}]}]},
            Sourceror.Zipper.node(left_zipper)
          ) or
            match?(
              {:@, _, [{:permit_action, _, [^action]}]},
              Sourceror.Zipper.node(left_zipper)
            )
      end
    end

    defp extract_event_name({:def, _, [{:handle_event, _, [name_node | _]}, _]}),
      do: unwrap_string(name_node)

    defp extract_event_name({:def, _, [{:when, _, [{:handle_event, _, [name_node | _]}, _]}, _]}),
      do: unwrap_string(name_node)

    defp extract_event_name(_), do: nil

    defp unwrap_string({:__block__, _, [value]}) when is_binary(value), do: value
    defp unwrap_string(value) when is_binary(value), do: value
    defp unwrap_string(_), do: nil

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
