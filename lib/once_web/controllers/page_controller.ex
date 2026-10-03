defmodule OnceWeb.PageController do
  use OnceWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
