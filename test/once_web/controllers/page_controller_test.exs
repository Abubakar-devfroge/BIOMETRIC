defmodule OnceWeb.PageControllerTest do
  use OnceWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "<main"
  end
end
