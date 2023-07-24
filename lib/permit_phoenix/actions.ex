defmodule Permit.Phoenix.Actions do
  @moduledoc """
  Extends the predefined `Permit.Actions.CrudActions` module and defines the following action mapping - usually applicable for most Phoenix applications:

  | **Action** | **Required permission** |
  |------------|-------------------------|
  | `:index`   | `:read`                 |
  | `:show`    | `:read`                 |
  | `:edit`    | `:update`               |
  | `:new`     | `:create`               |
  | `:delete`  | itself                  |
  | `:update`  | itself                  |
  | `:create`  | itself                  |

  For more information on defining and mapping actions, see `Permit.Actions` documentation.
  """
  use Permit.Actions

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

  def singular_actions,
    do: [:show, :edit, :new]
end
