defmodule OnceWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  alias AshAuthentication.Phoenix.{
    Components,
    ConfirmLive,
    MagicSignInLive,
    ResetLive,
    SignInLive
  }

  # Reference for Ash Authentication Phoenix overrides:
  # https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html

  # Completely hide the banner
  override AshAuthentication.Phoenix.Components.Banner do
    set :root_class, "hidden"
  end

  # Page Containers: Center-aligned page views with theme background
  override SignInLive do
    set :root_class,
        "bg-base-100 text-base-content flex items-center justify-center px-4 sm:px-6 md:px-8 min-h-[90dvh]"
  end

  override ResetLive do
    set :root_class,
        "min-h-screen bg-base-100 text-base-content flex items-center justify-center px-4 sm:px-6 md:px-8"
  end

  override ConfirmLive do
    set :root_class,
        "min-h-screen bg-base-100 text-base-content flex items-center justify-center px-4 sm:px-6 md:px-8"
  end

  override MagicSignInLive do
    set :root_class,
        "min-h-screen bg-base-100 text-base-content flex items-center justify-center px-4 sm:px-6 md:px-8"
  end

  # Strategy Containers: Expanded max-w to give the form comfortable room
  override Components.SignIn do
    set :root_class, "w-full max-w-lg mx-auto"
    set :strategy_class, "bg-base-100  w-full p-8 sm:p-10 rounded-2xl"
  end

  override Components.Reset do
    set :root_class, "w-full max-w-lg mx-auto"
    set :strategy_class, "bg-base-100 w-full p-8 sm:p-10 "
  end

  override Components.Confirm do
    set :root_class, "w-full max-w-lg mx-auto"
    set :strategy_class, "bg-base-100 w-full p-8 sm:p-10 "
  end

  override Components.MagicLink do
    set :root_class, "bg-base-100 border border-base-200 w-full max-w-lg p-8 sm:p-10  mx-auto"
  end

  # Password Form Toggles & Secondary Text with cleaner spacing
  override Components.Password do
    set :form_class, "flex flex-col gap-4 w-full"

    set :interstitial_class,
        "flex flex-row justify-between content-between text-sm font-medium text-base-content/70"

    set :toggler_class,
        "link link-primary text-sm transition-colors duration-200"
  end

  # Inputs and Action Buttons (Password Strategy)
  override Components.Password.Input do
    set :slot_class, "w-full"
    set :label_class, "label text-sm font-medium mb-1"
    set :input_class, "input input-bordered w-full h-11"
    set :input_class_with_error, "input input-bordered input-error w-full h-11"
    set :submit_class, "btn btn-primary w-full h-11 mt-4"
  end

  # Inputs and Action Buttons (Magic Link Strategy)
  override Components.MagicLink.Input do
    set :slot_class, "w-full"
    set :label_class, "label text-sm font-medium mb-1"
    set :input_class, "input input-bordered w-full h-11"
    set :input_class_with_error, "input input-bordered input-error w-full h-11"
    set :submit_class, "btn btn-primary w-full h-11 mt-4"
  end
end
