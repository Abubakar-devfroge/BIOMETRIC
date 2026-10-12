defmodule OnceWeb.Navigation do
  use OnceWeb, :html

  attr :current_user, :map, default: nil
  slot :inner_block

  def navbar(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col bg-base-100 text-base-content">
      <!-- NAVBAR -->
      <header class="navbar bg-base-100  px-4 sm:px-6 lg:px-8">
        <!-- LEFT: LOGO -->
        <div class="flex-1">
          <.link navigate={~p"/"} class="btn btn-ghost normal-case text-xl p-0 hover:bg-transparent">
            <img src={~p"/images/logos.png"} alt="The tribe
            " class="h-10 w-auto" />
          </.link>
        </div>

        <!-- RIGHT: NAV -->
        <div class="flex-none gap-2">
          <%= if @current_user do %>
            <!-- USER DROPDOWN -->
            <div class="dropdown dropdown-end">
              <div tabindex="0" role="button" class="btn btn-ghost btn-circle avatar">
                <div class="w-10 rounded-full ring ring-primary/20 ring-offset-base-100 ring-offset-2">
                  <img
                    alt="User avatar"
                    src={~p"/images/male.svg"}
                  />
                </div>
              </div>
              <ul
                tabindex="0"
                class="menu menu-sm dropdown-content mt-3 z-50 p-2 shadow-lg bg-base-100 border border-base-200 rounded-box w-52"
              >
                <li class="menu-title px-4 py-2 border-b border-base-200">
                  <span class="text-xs font-normal text-base-content/70 truncate block">
                    {@current_user.email}
                  </span>
                </li>

                <li>
                  <.link href={~p"/sign-out"} class="py-2 text-error hover:bg-error/10">
                    Sign out
                  </.link>
                </li>
              </ul>
            </div>
          <% else %>
            <.link navigate={~p"/sign-in"} class="btn btn-primary btn-sm sm:btn-md">
              Sign in
            </.link>
          <% end %>
        </div>
      </header>

      <!-- MAIN CONTENT -->
      <main class="flex-1 px-4 sm:px-6 lg:px-8 py-6">
        {render_slot(@inner_block)}
      </main>
    </div>
    """
  end
end
