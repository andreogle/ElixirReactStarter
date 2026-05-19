defmodule WebTemplateWeb.Router do
  use WebTemplateWeb, :router

  import WebTemplateWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WebTemplateWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Inertia.Plug
    plug :fetch_current_user
    plug WebTemplateWeb.Plugs.SharedData
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Public pages — anyone can hit these.
  scope "/", WebTemplateWeb do
    pipe_through :browser

    get "/", PageController, :home
    # Confirmation links: user clicks /confirm-email?token=... from the
    # email. No matching POST — the link itself is the action.
    get "/confirm-email", AuthController, :confirm_email
    get "/resend-confirmation", AuthController, :resend_confirmation_page
    post "/resend-confirmation", AuthController, :resend_confirmation
  end

  # Guest-only — already-logged-in users get bounced to /dashboard.
  scope "/", WebTemplateWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

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
  scope "/", WebTemplateWeb do
    pipe_through [:browser, :require_authenticated_user]

    delete "/logout", AuthController, :logout

    get "/settings", SettingsController, :show
    put "/settings/password", SettingsController, :update_password
    delete "/settings/account", SettingsController, :delete_account
  end

  scope "/", WebTemplateWeb do
    pipe_through :api

    # Liveness probe for load balancers / k8s / uptime monitors. Cheap
    # by design — no DB, no external calls.
    get "/health", HealthController, :show
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:web_template, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WebTemplateWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
