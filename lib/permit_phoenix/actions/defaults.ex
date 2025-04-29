defmodule Permit.Phoenix.Actions.Defaults do
  @moduledoc """
  Provides default action groupings and singular actions for Phoenix controllers and live views.
  This module is used as a default implementation that can be overridden in individual modules.
  """

  use Permit.Actions

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
end
