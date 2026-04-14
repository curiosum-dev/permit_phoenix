if Version.match?(System.version(), ">= 1.15.0") and Code.ensure_loaded?(Igniter.Test) do
  defmodule Mix.Tasks.Permit.Patch.LiveViewTest do
    use ExUnit.Case

    import Igniter.Test

    defp project_with_live_view(live_view_code \\ nil) do
      code =
        live_view_code ||
          """
          defmodule TestWeb.NoteLive.Index do
            use Phoenix.LiveView

            def mount(_params, _session, socket) do
              {:ok, socket}
            end

            def render(assigns) do
              ~H"<div>Notes</div>"
            end
          end
          """

      test_project(
        files: %{
          "lib/test_web/live/note_live/index.ex" => code
        }
      )
    end

    describe "permit.patch.live_view" do
      test "adds use Permit.Phoenix.LiveView and resource_module to a bare LiveView" do
        igniter =
          project_with_live_view()
          |> Igniter.compose_task("permit.patch.live_view", [
            "TestWeb.NoteLive.Index",
            "Test.Note"
          ])
          |> apply_igniter!()

        source = Rewrite.source!(igniter.rewrite, "lib/test_web/live/note_live/index.ex")
        content = Rewrite.Source.get(source, :content)

        assert content =~ "use Permit.Phoenix.LiveView, authorization_module: Test.Authorization"
        assert content =~ "def resource_module, do: Test.Note"
      end

      test "resource_module is inserted before first function definition" do
        igniter =
          project_with_live_view()
          |> Igniter.compose_task("permit.patch.live_view", [
            "TestWeb.NoteLive.Index",
            "Test.Note"
          ])
          |> apply_igniter!()

        source = Rewrite.source!(igniter.rewrite, "lib/test_web/live/note_live/index.ex")
        content = Rewrite.Source.get(source, :content)

        resource_pos = :binary.match(content, "resource_module") |> elem(0)
        mount_pos = :binary.match(content, "def mount") |> elem(0)
        assert resource_pos < mount_pos
      end

      test "adds @permit_action annotation to handle_event with known action name" do
        live_view_code = """
        defmodule TestWeb.NoteLive.Index do
          use Phoenix.LiveView

          def mount(_params, _session, socket), do: {:ok, socket}

          def handle_event("delete", %{"id" => id}, socket) do
            {:noreply, socket}
          end
        end
        """

        igniter =
          project_with_live_view(live_view_code)
          |> Igniter.compose_task("permit.patch.live_view", [
            "TestWeb.NoteLive.Index",
            "Test.Note"
          ])
          |> apply_igniter!()

        source = Rewrite.source!(igniter.rewrite, "lib/test_web/live/note_live/index.ex")
        content = Rewrite.Source.get(source, :content)

        assert content =~ "@permit_action :delete"
      end

      test "does not annotate handle_event with unknown action name" do
        live_view_code = """
        defmodule TestWeb.NoteLive.Index do
          use Phoenix.LiveView

          def mount(_params, _session, socket), do: {:ok, socket}

          def handle_event("save", params, socket) do
            {:noreply, socket}
          end
        end
        """

        igniter =
          project_with_live_view(live_view_code)
          |> Igniter.compose_task("permit.patch.live_view", [
            "TestWeb.NoteLive.Index",
            "Test.Note"
          ])
          |> apply_igniter!()

        source = Rewrite.source!(igniter.rewrite, "lib/test_web/live/note_live/index.ex")
        content = Rewrite.Source.get(source, :content)

        refute content =~ "@permit_action"
      end

      test "does not add use Permit.Phoenix.LiveView if already present" do
        live_view_code = """
        defmodule TestWeb.NoteLive.Index do
          use Phoenix.LiveView
          use Permit.Phoenix.LiveView, authorization_module: Test.Authorization

          def mount(_params, _session, socket) do
            {:ok, socket}
          end
        end
        """

        igniter =
          project_with_live_view(live_view_code)
          |> Igniter.compose_task("permit.patch.live_view", [
            "TestWeb.NoteLive.Index",
            "Test.Note"
          ])
          |> apply_igniter!()

        source = Rewrite.source!(igniter.rewrite, "lib/test_web/live/note_live/index.ex")
        content = Rewrite.Source.get(source, :content)

        matches = Regex.scan(~r/use Permit\.Phoenix\.LiveView/, content)
        assert length(matches) == 1
      end
    end
  end
end
