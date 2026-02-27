defmodule DingleberryWeb.PageController do
  use DingleberryWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
