defmodule OnceWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use OnceWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="mx-auto w-full max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      {render_slot(@inner_block)}
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative flex w-28 shrink-0 items-center rounded-full border border-zinc-200 bg-zinc-50 p-0.5 dark:border-zinc-700 dark:bg-zinc-800">
      <div class={[
        "absolute top-0.5 left-0.5 h-[calc(100%-4px)] w-[calc((100%-4px)/3)] rounded-full bg-white shadow-sm dark:bg-zinc-600 transition-transform duration-150",
        "[[data-theme=light]_&]:translate-x-[100%]",
        "[[data-theme=dark]_&]:translate-x-[200%]",
        "[[data-theme-source=system]_&]:translate-x-0"
      ]}>
      </div>

      <button
        class="relative z-10 grid w-1/3 cursor-pointer place-items-center py-1.5"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        aria-label="System theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 text-zinc-600 dark:text-zinc-300" />
      </button>

      <button
        class="relative z-10 grid w-1/3 cursor-pointer place-items-center py-1.5"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        aria-label="Light theme"
      >
        <.icon name="hero-sun-micro" class="size-4 text-zinc-600 dark:text-zinc-300" />
      </button>

      <button
        class="relative z-10 grid w-1/3 cursor-pointer place-items-center py-1.5"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        aria-label="Dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4 text-zinc-600 dark:text-zinc-300" />
      </button>
    </div>
    """
  end
end
