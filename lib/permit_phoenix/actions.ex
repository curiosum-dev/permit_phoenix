defmodule Permit.Phoenix.Actions do
  @moduledoc """
  Provides default action groupings and singular actions for Phoenix controllers and live views.
  This module is used as a default implementation that can be overridden in individual modules.


  Also, allows inferring actions from a Phoenix router module for convenience, so that the actions module
  does not need to repeat action names already living in controllers.

  Example:

      defmodule MyApp.Router do
        # ...

        get("/items/:id", MyApp.ItemController, :view)
      end

      defmodule MyApp.Actions do
        # Merge the actions from the router into the default grouping schema.
        use Permit.Phoenix.Actions, router: MyApp.Router
      end

      defmodule MyApp.Permissions do
        # Use the actions module to define permissions.
        use Permit.Permissions, actions_module: MyApp.Actions

        def can(:admin = _role) do
          permit()
          |> all(Item)
        end

        # The `view` action is automatically added to the grouping schema
        # and hence available as a `view/2`function when defining permissions.
        def can(:owner = _role) do
          permit()
          |> view(Item)
          |> all(Item, fn user, item -> item.owner_id == user.id end)
        end

      end
  """

  use Permit.Actions

  defmacro __using__(opts) do
    quote do
      use Permit.Actions

      def grouping_schema do
        unquote(__MODULE__).grouping_schema()
        |> unquote(__MODULE__).merge_from_router(unquote(opts)[:router])
      end

      def singular_actions do
        unquote(__MODULE__).singular_actions()
      end
    end
  end

  @doc """
  Returns the default action grouping schema for Phoenix applications.
  """
  @impl Permit.Actions
  def grouping_schema do
    %{
      new: [:create],
      index: [:read],
      show: [:read],
      edit: [:update]
    }
    |> Map.merge(crud_grouping())
  end

  @doc """
  Returns the list of actions that operate on a single resource.
  """
  def singular_actions do
    [:show, :edit, :new, :delete, :update]
  end

  def merge_from_router(grouping_schema, router_module) do
    actions_from_router(router_module)
    |> Enum.reduce(grouping_schema, fn action, acc ->
      if !Map.has_key?(acc, action), do: Map.put(acc, action, []), else: acc
    end)
  end

  defp actions_from_router(router_module) do
    router_module.__routes__()
    |> Stream.filter(fn route ->
      is_atom(route.plug_opts) and is_atom(route.plug) and Code.ensure_loaded?(route.plug) and
        function_exported?(route.plug, route.plug_opts, 2)
    end)
    |> Stream.map(fn route -> route.plug_opts end)
    |> Enum.uniq()
  end
end
