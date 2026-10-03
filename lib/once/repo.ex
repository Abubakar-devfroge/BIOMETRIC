defmodule Once.Repo do
  use Ecto.Repo,
    otp_app: :once,
    adapter: Ecto.Adapters.Postgres
end
