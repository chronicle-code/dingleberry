defmodule DingleberryWeb.Router do
  use DingleberryWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DingleberryWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DingleberryWeb do
    pipe_through :browser

    live "/", DashboardLive, :index
    live "/history", HistoryLive, :index
    live "/policy", PolicyLive, :index
    live "/sessions", SessionsLive, :index
  end

  # LLM Tools API
  scope "/api/v1", DingleberryWeb.API do
    pipe_through :api

    get "/tools", ToolsController, :index
    get "/tools/:name", ToolsController, :show
    post "/tools/:name/run", ToolsController, :run
  end

  # MCP SSE/HTTP transport endpoints
  scope "/mcp" do
    pipe_through :api

    get "/sse", DingleberryWeb.MCPController, :sse
    post "/message", DingleberryWeb.MCPController, :message
  end
end
