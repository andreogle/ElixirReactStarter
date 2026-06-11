defmodule ElixirReactStarterWeb.Router do
  use ElixirReactStarterWeb, :router

  import ElixirReactStarterWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ElixirReactStarterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Inertia.Plug
    plug :fetch_current_user
    plug ElixirReactStarterWeb.Plugs.SharedData
  end

  # CSP lives in its own pipeline so dev tooling (the Swoosh mailbox
  # preview, which renders email bodies in a nested same-origin iframe)
  # can run through :browser alone. The mailbox iframe is blocked by
  # `frame-ancestors 'none'`, so those local-only routes skip :csp.
  pipeline :csp do
    plug ElixirReactStarterWeb.Plugs.ContentSecurityPolicy
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Public pages — anyone can hit these.
  scope "/", ElixirReactStarterWeb do
    pipe_through [:browser, :csp]

    get "/", PageController, :home
    # Confirmation links: user clicks /confirm-email?token=... from the
    # email. No matching POST — the link itself is the action.
    get "/confirm-email", AuthController, :confirm_email
    get "/resend-confirmation", AuthController, :resend_confirmation_page
    post "/resend-confirmation", AuthController, :resend_confirmation
    # Locale change works for anonymous + authenticated. Cookie always
    # set; user.locale is also written when signed in.
    put "/locale", LocaleController, :update
  end

  # Guest-only — already-logged-in users get bounced to /dashboard.
  scope "/", ElixirReactStarterWeb do
    pipe_through [:browser, :csp, :redirect_if_user_is_authenticated]

    get "/login", AuthController, :login_page
    post "/login", AuthController, :login
    get "/register", AuthController, :register_page
    post "/register", AuthController, :register
    get "/forgot-password", AuthController, :forgot_password_page
    post "/forgot-password", AuthController, :forgot_password
    get "/reset-password", AuthController, :reset_password_page
    post "/reset-password", AuthController, :reset_password
  end

  # Authenticated — bounced to /login if not.
  scope "/", ElixirReactStarterWeb do
    pipe_through [:browser, :csp, :require_authenticated_user]

    get "/dashboard", DashboardController, :show
    delete "/logout", AuthController, :logout

    get "/settings", SettingsController, :show
    put "/settings/email", SettingsController, :update_email
    # Applies a pending email change. Opening the link from the
    # new-address email (while signed in) is the action — no matching
    # POST. Distinct from the public /confirm-email route, which activates
    # a brand-new account and logs the user in; this one swaps the email
    # on an already-active, signed-in account.
    get "/settings/email/apply-change", SettingsController, :confirm_email
    put "/settings/password", SettingsController, :update_password
    delete "/settings/account", SettingsController, :delete_account
  end

  scope "/", ElixirReactStarterWeb do
    pipe_through :api

    # Liveness probe for load balancers / k8s / uptime monitors. Cheap
    # by design — no DB, no external calls.
    get "/health", HealthController, :show

    # Readiness probe — checks the DB is reachable before declaring the
    # instance ready to take traffic. Returns 503 when the pool can't
    # answer, so orchestrators hold traffic until dependencies are up.
    get "/health/ready", HealthController, :ready
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:elixir_react_starter, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ElixirReactStarterWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    # E2E fixture provisioning. JSON only — the Playwright suite (assets/e2e)
    # POSTs here to mint a confirmed user and skip the email-link round-trip.
    # See ElixirReactStarterWeb.DevE2EController.
    scope "/dev", ElixirReactStarterWeb do
      pipe_through :api

      post "/e2e/users", DevE2EController, :create
    end
  end
end
