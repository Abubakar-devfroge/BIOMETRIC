defmodule OnceWeb.Router do
  use OnceWeb, :router

  import Oban.Web.Router
  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OnceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  # Protected Application Routes
  scope "/", OnceWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated_routes,
      on_mount: [{OnceWeb.LiveUserAuth, :live_user_required}] do
      live "/attendance", AttendanceLive

      live "/employees", EmployeeLive.Index, :index
      live "/employees/new", EmployeeLive.Form, :new
      live "/employees/:id/edit", EmployeeLive.Form, :edit

      live "/employees/:id", EmployeeLive.Show, :show
      live "/employees/:id/show/edit", EmployeeLive.Show, :edit
    end
  end

  # Public & Authentication Routes
  scope "/", OnceWeb do
    pipe_through :browser

    ash_authentication_live_session :home,
      on_mount: [{OnceWeb.LiveUserAuth, :live_user_optional}] do
      live "/", DashboardLive
    end

    auth_routes AuthController, Once.Accounts.User, path: "/auth"

    sign_out_route AuthController, "/sign-out",
      overrides: [OnceWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{OnceWeb.LiveUserAuth, :live_no_user}],
                  overrides: [OnceWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    reset_route auth_routes_prefix: "/auth",
                overrides: [OnceWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    confirm_route Once.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [OnceWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    magic_sign_in_route(Once.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [OnceWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )
  end

  # Dev & Internal Tools
  if Application.compile_env(:once, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: OnceWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    scope "/" do
      pipe_through :browser

      oban_dashboard("/oban")
    end
  end

  if Application.compile_env(:once, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end
