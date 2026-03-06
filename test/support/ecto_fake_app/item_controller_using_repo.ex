defmodule Permit.EctoFakeApp.ItemControllerUsingRepo do
  @moduledoc false
  use Phoenix.Controller, formats: [html: "View"]

  alias Permit.EctoFakeApp.{Authorization, Item, Repo}

  use Permit.Phoenix.Controller,
    authorization_module: Authorization,
    resource_module: Item,
    except: [:action_without_authorizing],
    fallback_path: "/?foo"

  def index(conn, _params), do: text(conn, "listing all items")

  def create(conn, %{"item" => item_params} = params) do
    auth_opts =
      case params["_authorize_as"] do
        "update" -> [action: :update]
        "create" -> [action: :create]
        _ -> []
      end

    auth_opts =
      if params["_custom_unauthorized"] do
        Keyword.put(auth_opts, :on_unauthorized, fn _action, conn ->
          conn
          |> put_flash(:error, "Custom denied.")
          |> redirect(to: "/custom_denied")
          |> halt()
        end)
      else
        auth_opts
      end

    case authorize_with_transaction(
           conn,
           fn -> Repo.insert(Item.changeset(%Item{}, item_params)) end,
           auth_opts
         ) do
      {:ok, item} -> text(conn, "created item #{item.id}")
      {:error, %Ecto.Changeset{}} -> text(conn, "validation error")
      {:error, conn} -> conn
    end
  end

  def show(conn, _params) do
    text(conn, inspect(conn.assigns[:loaded_resource]))
  end

  def edit(conn, _params), do: text(conn, inspect(conn.assigns[:loaded_resource]))
  def delete(conn, params), do: text(conn, "deleting item #{params["id"]}")
  def details(conn, _params), do: text(conn, inspect(conn.assigns[:loaded_resource]))
  def action_without_authorizing(conn, _params), do: text(conn, "okay")
end
