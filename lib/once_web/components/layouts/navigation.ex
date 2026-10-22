defmodule OnceWeb.Navigation do
  use OnceWeb, :html

  attr :current_user, :map, default: nil
  slot :inner_block

  def navbar(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col bg-slate-50 text-zinc-900 dark:bg-zinc-950 dark:text-zinc-100">
      <header class="sticky top-0 z-40 border-b border-zinc-200 bg-white/90 backdrop-blur dark:border-zinc-800 dark:bg-zinc-900/90">
        <div class="mx-auto flex h-16 w-full max-w-7xl items-center justify-between gap-4 px-4 sm:px-6 lg:px-8">
          <div class="flex min-w-0 items-center gap-3">
            <.link
              navigate={~p"/"}
              class="shrink-0 rounded-md focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-indigo-600"
            >
              <img src={~p"/images/logos.webp"} alt="The Tribe" class="h-9 w-auto" />
            </.link>

            <nav :if={@current_user} class="hidden items-center gap-1 md:flex" aria-label="Main">
              <.nav_link href={~p"/"} label="Dashboard" request_path={assigns[:request_path]} />
              <.nav_link
                href={~p"/attendance"}
                label="Attendance"
                request_path={assigns[:request_path]}
              />
              <.nav_link
                href={~p"/employees"}
                label="Employees"
                request_path={assigns[:request_path]}
              />
            </nav>
          </div>

          <div class="flex flex-none items-center gap-2 sm:gap-3">
            <Layouts.theme_toggle />

            <%= if @current_user do %>
              <details class="relative">
                <summary class="flex h-9 w-9 cursor-pointer list-none items-center justify-center rounded-full ring-zinc-200 transition hover:ring-4 dark:ring-zinc-700 [&::-webkit-details-marker]:hidden">
                  <img
                    alt="User avatar"
                    src={~p"/images/male.svg"}
                    class="h-9 w-9 rounded-full border border-zinc-200 dark:border-zinc-700"
                  />
                </summary>

                <div
                  id="user-menu"
                  role="menu"
                  class="absolute right-0 z-50 mt-2 w-56 overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-lg dark:border-zinc-700 dark:bg-zinc-900"
                >
                  <div class="border-b border-zinc-200 px-4 py-3 dark:border-zinc-700">
                    <p class="truncate text-sm font-medium text-zinc-900 dark:text-zinc-100">
                      {@current_user.email}
                    </p>
                  </div>

                  <nav class="flex flex-col py-1 md:hidden" aria-label="Mobile">
                    <.link
                      navigate={~p"/"}
                      class="px-4 py-2 text-sm text-zinc-700 hover:bg-zinc-50 dark:text-zinc-300 dark:hover:bg-zinc-800"
                    >
                      Dashboard
                    </.link>
                    <.link
                      navigate={~p"/attendance"}
                      class="px-4 py-2 text-sm text-zinc-700 hover:bg-zinc-50 dark:text-zinc-300 dark:hover:bg-zinc-800"
                    >
                      Attendance
                    </.link>
                    <.link
                      navigate={~p"/employees"}
                      class="px-4 py-2 text-sm text-zinc-700 hover:bg-zinc-50 dark:text-zinc-300 dark:hover:bg-zinc-800"
                    >
                      Employees
                    </.link>
                    <div class="my-1 border-t border-zinc-200 dark:border-zinc-700"></div>
                  </nav>

                  <.link
                    href={~p"/sign-out"}
                    class="block px-4 py-2.5 text-sm font-medium text-red-600 hover:bg-red-50 dark:text-red-400 dark:hover:bg-red-900/30"
                  >
                    Sign out
                  </.link>
                </div>
              </details>
            <% else %>
              <.link
                navigate={~p"/sign-in"}
                class="rounded-lg bg-indigo-600 px-3.5 py-2 text-sm font-semibold text-white shadow-xs transition-colors duration-150 hover:bg-indigo-500"
              >
                Sign in
              </.link>
            <% end %>
          </div>
        </div>
      </header>

      <main class="flex-1">
        {render_slot(@inner_block)}
      </main>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :request_path, :string, default: nil

  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      aria-current={@request_path == @href && "page"}
      class={[
        "rounded-md px-3 py-2 text-sm font-medium transition-colors",
        @request_path == @href && "bg-zinc-100 text-zinc-900 dark:bg-zinc-800 dark:text-zinc-100",
        @request_path != @href &&
          "text-zinc-600 hover:bg-zinc-100 hover:text-zinc-900 dark:text-zinc-400 dark:hover:bg-zinc-800 dark:hover:text-zinc-100"
      ]}
    >
      {@label}
    </.link>
    """
  end
end
