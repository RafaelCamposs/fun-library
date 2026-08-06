defmodule FunLibraryWeb.Router do
  use FunLibraryWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  get "/health", FunLibraryWeb.HealthController, :index

  scope "/api", FunLibraryWeb do
    pipe_through :api

    get "/stats", StatsController, :summary
    get "/reading_list_entries/:id/stats", StatsController, :entry

    resources "/books", BookController, except: [:new, :edit]

    post "/book_lookups", BookLookupController, :create

    resources "/reading_list_entries", ReadingListEntryController, except: [:new, :edit] do
      resources "/reading_sessions", SessionController, only: [:index, :create]
    end

    patch "/reading_list_entries/:id/pages", ReadingListEntryController, :update_pages

    resources "/reading_sessions", SessionController, only: [:show, :delete]
    patch "/reading_sessions/:id/finish", SessionController, :finish

    resources "/reading_goals", GoalController, except: [:new, :edit]
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:fun_library, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: FunLibraryWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
