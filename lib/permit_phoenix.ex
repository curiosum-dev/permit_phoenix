defmodule Permit.Phoenix do
  @moduledoc """
  Phoenix, Plug and LiveView integrations integration for [Permit](https://github.com/curiosum-dev/permit).

  In Phoenix controller actions as well as LiveView modules, based on the resource configured for the current controller or LiveView (e.g. an `Article`), the current user, and the action (determined by the controller action or `:live_action`), it typically performs the following operations:application

  1. Based on current params, typically an ID parameter, preload a record which is the subject of the current action. This is done either from the DB when `Permit.Ecto` is used or in a different manner.

  2. Call to the application's authorization module (the one that has `use Permit` - refer to [docs for `Permit`](https://hexdocs.pm/permit/Permit.html#module-check-a-user-s-authorization-to-perform-an-action-on-a-resource) for examples) to ask whether the preloaded record is authorized to perform the current controller action.

  3. Expose the loaded record into `assigns` if authorized, or perform a defined action (e.g. redirect) otherwise.

  Therefore, whereas in plain Phoenix the following could be written:
  ```elixir
  import MyApp.Authorization

  def show(conn, %{"id" => id} = params) do
    article = MyApp.Repo.get(MyApp.Article, id)
    user = conn.assigns.current_user

    if can(user) |> read?(article) do
      conn
      |> render(:show, loaded_resource: article)
    else
      conn
      |> put_flash(:error, "You do not have permission to perform this action.")
      |> redirect(to: "/")
    end
  end
  ```

  When using `Permit.Phoenix`, it becomes:
  ```elixir
  use Permit.Phoenix.Controller,
    authorization_module: MyApp.Authorization,
    resource_module: MyApp.Article

  def show(conn, params) do
    render(conn, :show)
  end
  ```

  That's it - the preload, the current user fetching, the assignment of loaded record and the handling of authorization errors is automatic.

  The way authorization errors are handled, the manner of loading records from the Ecto Repo or elsewhere, and many other parameters, are customizable - see `Permit.Phoenix.Controller` and `Permit.Phoenix.LiveView` for more information.
  """
end
