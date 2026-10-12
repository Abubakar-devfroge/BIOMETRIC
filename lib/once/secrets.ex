defmodule Once.Secrets do
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], Once.Accounts.User, _opts, _context) do
    Application.fetch_env(:once, :token_signing_secret)
  end
end
