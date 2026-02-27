defmodule DingleberryWeb.PageControllerTest do
  use DingleberryWeb.ConnCase

  test "GET / renders dashboard", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Dingleberry Dashboard"
  end
end
