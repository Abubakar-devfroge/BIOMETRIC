defmodule OnceWeb.DashboardLive do
  @moduledoc """
  Root page. Renders a live marketing page for guests and a data dashboard
  for signed-in users.
  """
  use OnceWeb, :live_view

  require Ash.Query

  alias Once.Biotime.{Employee, Reports, Sync}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign_new(:current_user, fn -> nil end)
      |> assign(:syncing?, false)

    socket =
      if socket.assigns.current_user do
        load_dashboard_data(socket)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("trigger_sync", _params, socket) do
    send(self(), :run_delta_sync)
    {:noreply, assign(socket, :syncing?, true)}
  end

  @impl true
  def handle_info(:run_delta_sync, socket) do
    case Sync.sync_recent() do
      {:ok, count} ->
        socket =
          socket
          |> assign(:syncing?, false)
          |> put_flash(:info, "Sync complete: #{count} records updated.")
          |> load_dashboard_data()

        {:noreply, socket}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:syncing?, false)
         |> put_flash(:error, "Sync failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <%= if @current_user do %>
      <div class="mx-auto w-full max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <%!-- Header --%>
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-2xl font-semibold tracking-tight text-zinc-900 dark:text-zinc-100">
              Dashboard
            </h1>
            <p class="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
              Company attendance overview for {Calendar.strftime(@today, "%A, %d %B %Y")}
            </p>
          </div>

          <button
            type="button"
            phx-click="trigger_sync"
            disabled={@syncing?}
            class="inline-flex cursor-pointer items-center justify-center gap-2 rounded-lg border border-zinc-300 bg-white px-3.5 py-2 text-sm font-semibold text-zinc-800 shadow-xs transition-colors duration-150 hover:bg-zinc-50 disabled:pointer-events-none disabled:opacity-50 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-100 dark:hover:bg-zinc-700"
          >
            <svg
              :if={@syncing?}
              class="h-4 w-4 animate-spin"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <circle
                class="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                stroke-width="4"
              />
              <path
                class="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
              />
            </svg>
            <span :if={!@syncing?}>
              <.icon name="hero-arrow-path" class="size-4" />
            </span>
            {if @syncing?, do: "Syncing...", else: "Sync data"}
          </button>
        </div>

        <%!-- Stat cards --%>
        <div class="mt-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
          <.stat_card
            label="Active employees"
            value={@stats.employees}
            trailing="Tracked for attendance"
          />
          <.stat_card
            label="Present today"
            value={@stats.present}
            trailing="Logged at least one punch"
          />
          <.stat_card
            label="Clocked in"
            value={@stats.in_building}
            trailing="On site, no exit punch yet"
          />
          <.stat_card label="Absent today" value={@stats.absent} trailing="Zero punches recorded" />
        </div>

        <%!-- Main grid --%>
        <div class="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-3">
          <%!-- Attendance rate + attendance today --%>
          <div class="rounded-xl border border-zinc-200 bg-white shadow-xs dark:border-zinc-800 dark:bg-zinc-900 lg:col-span-2">
            <div class="flex items-center justify-between border-b border-zinc-200 px-5 py-4 dark:border-zinc-800">
              <h2 class="text-sm font-semibold text-zinc-900 dark:text-zinc-100">Today's activity</h2>
              <.link
                navigate={~p"/attendance"}
                class="text-sm font-medium text-indigo-600 hover:text-indigo-500 dark:text-indigo-400"
              >
                View all
              </.link>
            </div>

            <div :if={@activity == []} class="px-5 py-10 text-center">
              <.icon name="hero-clock" class="mx-auto size-8 text-zinc-300 dark:text-zinc-600" />
              <p class="mt-3 text-sm text-zinc-500 dark:text-zinc-400">
                No punches have been recorded today yet.
              </p>
            </div>

            <ul
              :if={@activity != []}
              id="todays-activity"
              class="flex flex-col divide-y divide-zinc-200 dark:divide-zinc-800"
            >
              <li
                :for={event <- @activity}
                class="flex items-center gap-4 px-5 py-3 transition-colors hover:bg-zinc-50 dark:hover:bg-zinc-800/50"
              >
                <span class={[
                  "flex size-9 shrink-0 items-center justify-center rounded-full",
                  event.type == :clock_in &&
                    "bg-emerald-50 text-emerald-600 dark:bg-emerald-900/40 dark:text-emerald-400",
                  event.type == :clock_out &&
                    "bg-zinc-100 text-zinc-500 dark:bg-zinc-800 dark:text-zinc-400"
                ]}>
                  <.icon
                    name={
                      if(event.type == :clock_in,
                        do: "hero-arrow-right-on-rectangle",
                        else: "hero-arrow-left-on-rectangle"
                      )
                    }
                    class="size-4"
                  />
                </span>
                <div class="min-w-0 flex-1">
                  <p class="truncate text-sm font-medium text-zinc-900 dark:text-zinc-100">
                    {event.name}
                  </p>
                  <p class="truncate text-xs text-zinc-500 dark:text-zinc-400">
                    {event.department || "—"}
                  </p>
                </div>
                <div class="text-right">
                  <p class="text-sm font-medium tabular-nums text-zinc-900 dark:text-zinc-100">
                    {Calendar.strftime(event.at, "%H:%M:%S")}
                  </p>
                  <p class="text-xs text-zinc-500 dark:text-zinc-400">
                    {if(event.type == :clock_in, do: "Clock in", else: "Clock out")}
                  </p>
                </div>
              </li>
            </ul>
          </div>

          <%!-- Quick actions --%>
          <div class="rounded-xl border border-zinc-200 bg-white shadow-xs dark:border-zinc-800 dark:bg-zinc-900">
            <div class="border-b border-zinc-200 px-5 py-4 dark:border-zinc-800">
              <h2 class="text-sm font-semibold text-zinc-900 dark:text-zinc-100">Quick actions</h2>
            </div>

            <div class="flex flex-col p-5 gap-3">
              <.link
                navigate={~p"/employees"}
                class="flex items-center gap-3 rounded-lg border border-zinc-200 p-3 transition-colors hover:border-indigo-300 hover:bg-indigo-50/50 dark:border-zinc-800 dark:hover:border-indigo-700 dark:hover:bg-indigo-900/20"
              >
                <span class="flex size-9 shrink-0 items-center justify-center rounded-lg bg-indigo-50 text-indigo-600 dark:bg-indigo-900/40 dark:text-indigo-400">
                  <.icon name="hero-users" class="size-5" />
                </span>
                <span>
                  <span class="block text-sm font-medium text-zinc-900 dark:text-zinc-100">Employees</span>
                  <span class="block text-xs text-zinc-500 dark:text-zinc-400">Directory & records</span>
                </span>
              </.link>

              <.link
                navigate={~p"/attendance"}
                class="flex items-center gap-3 rounded-lg border border-zinc-200 p-3 transition-colors hover:border-indigo-300 hover:bg-indigo-50/50 dark:border-zinc-800 dark:hover:border-indigo-700 dark:hover:bg-indigo-900/20"
              >
                <span class="flex size-9 shrink-0 items-center justify-center rounded-lg bg-indigo-50 text-indigo-600 dark:bg-indigo-900/40 dark:text-indigo-400">
                  <.icon name="hero-clipboard-document-list" class="size-5" />
                </span>
                <span>
                  <span class="block text-sm font-medium text-zinc-900 dark:text-zinc-100">Attendance reports</span>
                  <span class="block text-xs text-zinc-500 dark:text-zinc-400">Daily, absentees & summaries</span>
                </span>
              </.link>
            </div>

            <div class="border-t border-zinc-200 px-5 py-4 dark:border-zinc-800">
              <p class="text-sm text-zinc-700 dark:text-zinc-300">
                <span class="font-semibold">{abs(@stats.employees - @stats.present)}</span>
                active employees have no punches today, and
                <span class="font-semibold">{@stats.in_building}</span>
                {if @stats.in_building == 1, do: "is", else: "are"} still on site.
              </p>
            </div>
          </div>
        </div>
      </div>
    <% else %>
      <%!-- Marketing landing --%>
      <section class="overflow-hidden bg-white dark:bg-zinc-900">
        <div class="mx-auto max-w-7xl px-4 pb-16 pt-16 sm:px-6 sm:pt-24 lg:px-8">
          <div class="flex flex-col items-center gap-12 lg:flex-row lg:items-center">
            <div class="w-full lg:w-1/2">
              <h1 class="text-4xl font-semibold leading-tight tracking-tight text-zinc-900 sm:text-5xl lg:text-6xl dark:text-zinc-50">
                Grow Smarter.
                <span class="block text-indigo-600 dark:text-indigo-400">Work Faster.</span>
              </h1>
              <p class="mt-6 max-w-lg text-lg text-zinc-600 dark:text-zinc-400">
                Clock. Track. Manage. Live attendance data straight from your biometric devices —
                payroll-ready, in real time.
              </p>
              <div class="mt-8 flex flex-col gap-3 sm:flex-row">
                <.link
                  navigate={~p"/sign-in"}
                  class="inline-flex items-center justify-center rounded-lg bg-indigo-600 px-5 py-2.5 text-sm font-semibold text-white shadow-xs transition-colors duration-150 hover:bg-indigo-500"
                >
                  Sign in
                </.link>
                <.link
                  navigate={~p"/register"}
                  class="inline-flex items-center justify-center rounded-lg border border-zinc-300 bg-white px-5 py-2.5 text-sm font-semibold text-zinc-800 shadow-xs transition-colors duration-150 hover:bg-zinc-50 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-100 dark:hover:bg-zinc-700"
                >
                  Create account
                </.link>
              </div>
            </div>

            <div class="relative w-full lg:w-1/2">
              <div class="h-72 overflow-hidden rounded-2xl border border-zinc-200 shadow-lg sm:h-96 lg:h-auto dark:border-zinc-800">
                <img
                  class="h-full w-full object-cover object-center"
                  src={~p"/images/work.webp"}
                  alt="Workforce at work"
                  fetchpriority="high"
                />
              </div>
            </div>
          </div>
        </div>
      </section>

      <footer class="border-t border-zinc-200 bg-white dark:border-zinc-800 dark:bg-zinc-900">
        <div class="mx-auto grid max-w-7xl grid-cols-1 gap-10 px-4 py-12 sm:grid-cols-2 md:grid-cols-4 sm:px-6 lg:px-8">
          <aside class="space-y-4 md:col-span-2">
            <img
              src={~p"/images/logos.webp"}
              alt="The Tribe logo"
              class="h-10 w-auto"
              width="299"
              height="224"
              decoding="async"
              oncontextmenu="return false;"
            />
            <p class="max-w-xs text-sm leading-relaxed text-zinc-500 dark:text-zinc-400">
              Clock. Track. Manage. Attendance data for your entire workforce, in real time.
            </p>
          </aside>

          <nav class="space-y-3">
            <h3 class="text-sm font-semibold text-zinc-900 dark:text-zinc-100">Company</h3>
            <ul class="space-y-2 text-sm">
              <li>
                <a
                  href="https://www.craftinc.dev/"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-zinc-500 transition-colors hover:text-indigo-600 dark:text-zinc-400 dark:hover:text-indigo-400"
                >
                  About us
                </a>
              </li>
              <li>
                <a
                  href="https://www.craftinc.dev/"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-zinc-500 transition-colors hover:text-indigo-600 dark:text-zinc-400 dark:hover:text-indigo-400"
                >
                  Blog
                </a>
              </li>
            </ul>
          </nav>

          <nav class="space-y-3">
            <h3 class="text-sm font-semibold text-zinc-900 dark:text-zinc-100">Legal</h3>
            <ul class="space-y-2 text-sm">
              <li>
                <a
                  href="https://www.craftinc.dev/Privacy"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-zinc-500 transition-colors hover:text-indigo-600 dark:text-zinc-400 dark:hover:text-indigo-400"
                >
                  Terms of use
                </a>
              </li>
              <li>
                <a
                  href="https://www.craftinc.dev/Privacy"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-zinc-500 transition-colors hover:text-indigo-600 dark:text-zinc-400 dark:hover:text-indigo-400"
                >
                  Privacy policy
                </a>
              </li>
            </ul>
          </nav>
        </div>
      </footer>
    <% end %>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :trailing, :string, required: true

  defp stat_card(assigns) do
    ~H"""
    <div class="rounded-xl border border-zinc-200 bg-white p-5 shadow-xs transition-shadow hover:shadow-sm dark:border-zinc-800 dark:bg-zinc-900">
      <p class="text-sm text-zinc-500 dark:text-zinc-400">{@label}</p>
      <p class="mt-2 text-3xl font-semibold tracking-tight tabular-nums text-zinc-900 dark:text-zinc-50">
        {@value}
      </p>
      <p class="mt-1 text-xs text-zinc-500 dark:text-zinc-400">{@trailing}</p>
    </div>
    """
  end

  defp load_dashboard_data(socket) do
    today = Once.Time.nairobi_today()
    daily = Reports.daily_attendance(today, today)

    employees_count =
      Employee
      |> Ash.Query.filter(enable_att == true)
      |> Ash.Query.select([])
      |> Ash.count!()

    stats = %{
      employees: employees_count,
      present: length(daily),
      in_building: Enum.count(daily, & &1.missing_clock_out?),
      absent: Reports.absent_count_on_date(today)
    }

    activity =
      build_activity(daily)
      |> Enum.sort_by(& &1.at, {:desc, NaiveDateTime})
      |> Enum.take(12)

    socket
    |> assign(:today, today)
    |> assign(:stats, stats)
    |> assign(:activity, activity)
  end

  defp build_activity(daily_records) do
    Enum.flat_map(daily_records, fn record ->
      clock_in = %{
        at: record.clock_in,
        name: record.name,
        department: record.department,
        type: :clock_in
      }

      clock_out =
        if record.clock_out && record.clock_out != record.clock_in do
          [
            %{
              at: record.clock_out,
              name: record.name,
              department: record.department,
              type: :clock_out
            }
          ]
        else
          []
        end

      [clock_in | clock_out]
    end)
  end
end
