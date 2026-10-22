defmodule OnceWeb.DashboardLiveTest do
  use OnceWeb.ConnCase

  test "GET / renders marketing page for guests", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Sign in"
    assert html_response(conn, 200) =~ "Create account"
  end
end
