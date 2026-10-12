defmodule Once.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email
  """

  use AshAuthentication.Sender
  use OnceWeb, :verified_routes

  import Swoosh.Email

  alias Once.Mailer

  @impl true
  def send(user, token, _) do
    from_email = System.get_env("MAILER_FROM_EMAIL", "auth@craftinc.dev")

    new()
    |> from({"Biometric", from_email})
    |> to(to_string(user.email))
    |> subject("Reset your password")
    |> html_body(body(token: token))
    |> Mailer.deliver!()
  end

  defp body(params) do
    url = url(~p"/password-reset/#{params[:token]}")

    """
    <p>Click this link to reset your password:</p>
    <p><a href="#{url}">#{url}</a></p>
    """
  end
end