defmodule Once.Accounts do
  use Ash.Domain, otp_app: :once, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Once.Accounts.Token
    resource Once.Accounts.User
  end
end
