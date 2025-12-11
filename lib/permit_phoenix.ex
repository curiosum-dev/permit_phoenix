defmodule Permit.Phoenix do
  @moduledoc ~S"""
  Phoenix, Plug and LiveView integrations integration for [Permit](https://github.com/curiosum-dev/permit).

  In Phoenix controller actions as well as LiveView modules, based on the resource configured for the current
  controller or LiveView (e.g. an `Article`), the current user, and the action (determined by the controller
  action or `:live_action`), it typically performs the following operations:application

  1. Based on current params, typically an ID parameter, preload a record which is the subject of the current
  action. This is done either from the DB when `Permit.Ecto` is used or in a different manner.

  2. Call to the application's authorization module (the one that has `use Permit` - refer to [docs for
  `Permit`](https://hexdocs.pm/permit/Permit.html#module-check-a-user-s-authorization-to-perform-an-action-on-a-resource)
  for examples) to ask whether the preloaded record is authorized to perform the current controller action.

  3. Expose the loaded record into `assigns` if authorized, or perform a defined action (e.g. redirect)
  otherwise.

  ## Setup

  In your `mix.exs`, add `:permit_phoenix` to your dependencies. Also, add `:permit_ecto` unless you don't use
  Ecto for managing relationships between users and data and sourcing attributes important for authorization.

  ```
  def deps do
    [
      {:permit_phoenix, "~> 0.4.0"},
      {:permit_ecto, "~> 0.2.4"}
    ]
  end
  ```

  For convenience defining permissions using action names corresponding to controller and live actions,
  create an actions module that extends `Permit.Phoenix.Actions` and merges the actions from your router. This module
  also declares which actions are considered singular (operating on a single resource) or plural (operating on a
  list of resources).

  After configuring action names, configure and define your permissions [(see Permit docs for details)]
  (https://hexdocs.pm/permit/Permit.html#module-configure-define-your-permissions). With `Permit.Ecto`, use
  `Permit.Ecto.Permissions` in your permissions module.

  Once you've got a configured `MyApp.Authorization` module, use it in your controller and live view modules.

  ## Controller usage

  To setup a controller to use `Permit.Phoenix`, use `Permit.Phoenix.Controller`:
  ```elixir
  defmodule MyAppWeb.ArticleController do
    use Permit.Phoenix.Controller,
      authorization_module: MyApp.Authorization,
      resource_module: MyApp.Article

    def index(conn, params) do
      # @loaded_resources is assigned if authorized, containing the list of records
      render(conn, :index)
    end

    def show(conn, params) do
      # @loaded_resource is assigned if authorized, containing the loaded record
      render(conn, :show)
    end
  end
  ```

  By default, in `:show` and `:index`, Permit will check for the `:read` permission on the `MyApp.Article` resource
  by the current user (`@current_scope.user`). `Permit.Ecto` will generate a query filtered by permission conditions
  and to fetch the record (or records) by the `"id"` param, by default.
  If authorized, the record will be assigned to `@loaded_resource`. Otherwise, the `handle_unauthorized/2` callback
  will be called, which defaults to redirecting to `/`.

  You can customize the authorization check by overriding the `handle_unauthorized/2` callback.

  ```elixir
  @impl true
  def handle_unauthorized(action, conn) do
    redirect(conn, to: "/")
  end
  ```
  You can put the configuration in your main web module and override specific options in individual controllers.

  ```elixir
  defmodule MyAppWeb do
    def controller do
      quote do
        use Permit.Phoenix.Controller,
          authorization_module: MyApp.Authorization
      end
    end
  end

  defmodule MyAppWeb.ArticleController do
    use MyAppWeb, :controller

    @impl true
    def resource_module, do: MyApp.Article

    # Controller actions...
  end
  ```

  See `Permit.Phoenix.Controller` for more information on how to handle authorization errors, customize
  generated queries, and other available options and callbacks.

  That's it - the preload, the current user fetching, the assignment of loaded record and the handling of authorization errors is automatic.

  ## LiveView usage

  On mount, `Permit.Phoenix.LiveView` attaches hooks to the `handle_params/3` and `handle_event/3` callbacks to preload records
  and perform authorization:
  - at mount, hooked before the `mount/3` callback
  - during navigation, when `:live_action` changes - before `handle_params/3` is called
  - in event handling, when an event is triggered - before `handle_event/3` is called

  Action name is either taken from the `:live_action` defined for the current route, or - in event authorization - from an explicit
  mapping between event names and Permit action names using the `@permit_action` module attribute.

  Record ID is taken from the `"id"` param, by default - both in navigation and in event handling. In events that do not carry
  an ID param, the record currently assigned to `@loaded_resource` is used and reloaded to ensure permissions are evaluated against the
  latest data.

  To setup a LiveView to use `Permit.Phoenix`, use `Permit.Phoenix.LiveView`:
  ```elixir
  defmodule MyApp.ArticleLive.Show do
    use MyAppWeb, :live_view

    use Permit.Phoenix.LiveView,
      authorization_module: MyApp.Authorization,
      resource_module: MyApp.Article
  end
  ```

  Just like with controllers, you can put the configuration in your main web module and override specific options in individual LiveViews.
  ```elixir
  defmodule MyAppWeb do
    def live_view do
      quote do
        use Permit.Phoenix.LiveView,
          authorization_module: MyApp.Authorization
      end
    end
  end

  defmodule MyApp.ArticleLive.Show do
    use MyAppWeb, :live_view

    @impl true
    def resource_module, do: MyApp.Article
  end
  ```

  Param and event handlers put preloaded and authorized record in `@loaded_resource` or `@loaded_resources` assigns, respectively.
  For plural actions like `:index`, the records can be streamed to `@streams.loaded_resources` instead, if `:use_stream` option
  is set to `true`.

  ```elixir
  defmodule MyApp.ArticleLive.Index do
    use MyAppWeb, :live_view

    use Permit.Phoenix.LiveView,
      authorization_module: MyApp.Authorization,
      resource_module: MyApp.Article,
      use_stream?: true

    @impl true
    def handle_params(params, _url, socket) do
      # @streams.loaded_resources is assigned if authorized, containing the list of records
      {:noreply, socket}
    end

    @impl true
    @permit_action :delete
    def handle_event("delete", params, socket) do
      # @loaded_resource is assigned if authorized, containing the loaded record
      # Delete the record and stream the deletion to the client
    end
  end
  ```

  If authorization fails, `handle_unauthorized/2` is called, which can either `:cont` or `:halt` the processing.
  By default, it stays on the same page and displays a flash error message unless it's in the mounting phase or
  cannot determine the live referer.

  In events that do not carry an ID param (e.g. form updating with `"save"` and form data in the params), authorization
  to perform the current action in general is still performed - the record currently assigned to `@loaded_resource`
  is used and reloaded to ensure authorization correctness, unless `reload_on_event?/2` is overridden to `false`.

  See `Permit.Phoenix.LiveView` for more information on how to handle authorization errors, customize
  generated queries, and other available options and callbacks.

  """
end
