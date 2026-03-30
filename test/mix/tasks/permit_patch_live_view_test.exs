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

    test "uses custom authorization module" do
      igniter =
        project_with_live_view()
        |> Igniter.compose_task("permit.patch.live_view", [
          "TestWeb.NoteLive.Index",
          "Test.Note",
          "--authorization-module",
          "Test.Auth"
        ])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/live/note_live/index.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "authorization_module: Test.Auth"
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

      # Should appear exactly once
      matches = Regex.scan(~r/use Permit\.Phoenix\.LiveView/, content)
      assert length(matches) == 1

      # resource_module should be added
      assert content =~ "def resource_module, do: Test.Note"
    end

    test "is idempotent - does not duplicate resource_module" do
      live_view_code = """
      defmodule TestWeb.NoteLive.Index do
        use Phoenix.LiveView
        use Permit.Phoenix.LiveView, authorization_module: Test.Authorization

        @impl true
        def resource_module, do: Test.Note

        def mount(_params, _session, socket) do
          {:ok, socket}
        end
      end
      """

      project_with_live_view(live_view_code)
      |> Igniter.compose_task("permit.patch.live_view", [
        "TestWeb.NoteLive.Index",
        "Test.Note"
      ])
      |> assert_unchanged("lib/test_web/live/note_live/index.ex")
    end
  end
end
