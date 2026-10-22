defmodule OnceWeb.AttendanceLive do
  use OnceWeb, :live_view

  alias Once.Biotime.{Reports, Sync}

  @impl true
  def mount(_params, _session, socket) do
    today = Once.Time.nairobi_today()

    socket =
      socket
      |> assign(:page_title, "Attendance")
      |> assign(:active_tab, :daily)
      |> assign(:target_date, today)
      |> assign(:start_date, Date.beginning_of_month(today))
      |> assign(:end_date, today)
      |> assign(:syncing?, false)
      |> load_tab_data()

    {:ok, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    tab = String.to_existing_atom(tab)
    {:noreply, socket |> assign(:active_tab, tab) |> load_tab_data()}
  end

  @impl true
  def handle_event("change_date", %{"date" => date_str}, socket) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        {:noreply, socket |> assign(:target_date, date) |> load_tab_data()}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_range", %{"start_date" => s_str, "end_date" => e_str}, socket) do
    with {:ok, start_d} <- Date.from_iso8601(s_str),
         {:ok, end_d} <- Date.from_iso8601(e_str) do
      {:noreply,
       socket
       |> assign(:start_date, start_d)
       |> assign(:end_date, end_d)
       |> load_tab_data()}
    else
      _ -> {:noreply, socket}
    end
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
          |> load_tab_data()

        {:noreply, socket}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:syncing?, false)
         |> put_flash(:error, "Sync failed: #{inspect(reason)}")}
    end
  end

  defp load_tab_data(socket) do
    case socket.assigns.active_tab do
      :daily ->
        data = Reports.daily_attendance(socket.assigns.target_date, socket.assigns.target_date)
        assign(socket, :daily_records, data)

      :absent ->
        data = Reports.absent_on_date(socket.assigns.target_date)
        assign(socket, :absent_records, data)

      :summary ->
        data = Reports.hours_summary(socket.assigns.start_date, socket.assigns.end_date)
        assign(socket, :summary_records, data)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto w-full max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <Layouts.flash_group flash={@flash} />

      <%!-- Header --%>
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 class="text-2xl font-semibold tracking-tight text-zinc-900 dark:text-zinc-100">
            Attendance
          </h1>
          <p class="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
            Real-time biometric logs, absentees & payroll aggregates
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
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
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

      <%!-- Tabs + filters --%>
      <div class="mt-6">
        <div class="flex flex-col gap-4 border-b border-zinc-200 dark:border-zinc-800 md:flex-row md:items-center md:justify-between">
          <nav class="-mb-px flex gap-6" aria-label="Attendance tabs">
            <button
              :for={
                {tab, label} <- [
                  {:daily, "Daily attendance"},
                  {:absent, "Absentees"},
                  {:summary, "Range summary"}
                ]
              }
              phx-click="switch_tab"
              phx-value-tab={tab}
              class={[
                "-mb-px cursor-pointer whitespace-nowrap border-b-2 pb-3 text-sm font-medium transition-colors",
                @active_tab == tab &&
                  "border-indigo-600 text-indigo-600 dark:border-indigo-400 dark:text-indigo-400",
                @active_tab != tab &&
                  "border-transparent text-zinc-500 hover:border-zinc-300 hover:text-zinc-700 dark:text-zinc-400 dark:hover:border-zinc-600 dark:hover:text-zinc-300"
              ]}
            >
              {label}
            </button>
          </nav>

          <div class="flex flex-wrap items-center gap-2 pb-3 text-sm">
            <%= if @active_tab in [:daily, :absent] do %>
              <form phx-change="change_date" class="flex items-center gap-2">
                <label for="attendance-date" class="text-zinc-500 dark:text-zinc-400">Date</label>
                <input
                  id="attendance-date"
                  type="date"
                  name="date"
                  value={Date.to_iso8601(@target_date)}
                  class="cursor-pointer rounded-lg border border-zinc-300 bg-white px-2.5 py-1.5 text-sm text-zinc-900 focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/30 focus:outline-none dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-100"
                />
              </form>
            <% else %>
              <form phx-change="change_range" class="flex items-center gap-2">
                <label class="text-zinc-500 dark:text-zinc-400">From</label>
                <input
                  type="date"
                  name="start_date"
                  value={Date.to_iso8601(@start_date)}
                  class="cursor-pointer rounded-lg border border-zinc-300 bg-white px-2.5 py-1.5 text-sm text-zinc-900 focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/30 focus:outline-none dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-100"
                />
                <label class="text-zinc-500 dark:text-zinc-400">To</label>
                <input
                  type="date"
                  name="end_date"
                  value={Date.to_iso8601(@end_date)}
                  class="cursor-pointer rounded-lg border border-zinc-300 bg-white px-2.5 py-1.5 text-sm text-zinc-900 focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/30 focus:outline-none dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-100"
                />
              </form>
            <% end %>
          </div>
        </div>
      </div>

      <%!-- Daily attendance --%>
      <div
        :if={@active_tab == :daily}
        class="mt-6 overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-xs dark:border-zinc-800 dark:bg-zinc-900"
      >
        <div class="border-b border-zinc-200 px-5 py-4 text-sm dark:border-zinc-800">
          <span class="text-zinc-500 dark:text-zinc-400">
            {length(@daily_records)} records on
            <span class="font-medium text-zinc-900 dark:text-zinc-100">
              {Calendar.strftime(@target_date, "%d %b %Y")}
            </span>
          </span>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm text-left text-zinc-900 dark:text-zinc-100">
            <thead>
              <tr class="border-b border-zinc-200 bg-zinc-50 text-xs font-medium uppercase tracking-wider text-zinc-500 dark:border-zinc-800 dark:bg-zinc-800/60 dark:text-zinc-400">
                <th class="px-5 py-3">Code</th>
                <th class="px-5 py-3">Employee</th>
                <th class="px-5 py-3">Department</th>
                <th class="px-5 py-3">Clock in</th>
                <th class="px-5 py-3">Clock out</th>
                <th class="px-5 py-3 text-right">Hours</th>
                <th class="px-5 py-3 text-center">Punches</th>
                <th class="px-5 py-3">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-zinc-200 dark:divide-zinc-800">
              <tr
                :for={row <- @daily_records}
                class="transition-colors hover:bg-zinc-50 dark:hover:bg-zinc-800/50"
              >
                <td class="px-5 py-3.5 font-medium tabular-nums">{row.emp_code}</td>
                <td class="px-5 py-3.5 font-medium">{row.name}</td>
                <td class="px-5 py-3.5 text-zinc-500 dark:text-zinc-400">{row.department || "—"}</td>
                <td class="px-5 py-3.5 tabular-nums">
                  {Calendar.strftime(row.clock_in, "%H:%M:%S")}
                </td>
                <td class="px-5 py-3.5 tabular-nums">
                  {if row.clock_out, do: Calendar.strftime(row.clock_out, "%H:%M:%S"), else: "—"}
                </td>
                <td class="px-5 py-3.5 text-right font-medium tabular-nums">{row.hours_worked}</td>
                <td class="px-5 py-3.5 text-center tabular-nums text-zinc-500 dark:text-zinc-400">
                  {row.total_punches}
                </td>
                <td class="px-5 py-3.5">
                  <.status_badge status={row.status} />
                </td>
              </tr>
              <tr :if={@daily_records == []}>
                <td colspan="8" class="px-5 py-12 text-center text-zinc-400 dark:text-zinc-500">
                  No attendance records logged for this date.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <%!-- Absentees --%>
      <div
        :if={@active_tab == :absent}
        class="mt-6 overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-xs dark:border-zinc-800 dark:bg-zinc-900"
      >
        <div class="border-b border-zinc-200 px-5 py-4 text-sm dark:border-zinc-800">
          <span class="text-zinc-500 dark:text-zinc-400">
            {length(@absent_records)} staff with no punches on
            <span class="font-medium text-zinc-900 dark:text-zinc-100">
              {Calendar.strftime(@target_date, "%d %b %Y")}
            </span>
          </span>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm text-left text-zinc-900 dark:text-zinc-100">
            <thead>
              <tr class="border-b border-zinc-200 bg-zinc-50 text-xs font-medium uppercase tracking-wider text-zinc-500 dark:border-zinc-800 dark:bg-zinc-800/60 dark:text-zinc-400">
                <th class="px-5 py-3">Code</th>
                <th class="px-5 py-3">Employee</th>
                <th class="px-5 py-3">Department</th>
                <th class="px-5 py-3">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-zinc-200 dark:divide-zinc-800">
              <tr
                :for={emp <- @absent_records}
                class="transition-colors hover:bg-zinc-50 dark:hover:bg-zinc-800/50"
              >
                <td class="px-5 py-3.5 font-medium tabular-nums">{emp.emp_code}</td>
                <td class="px-5 py-3.5 font-medium">{emp.name}</td>
                <td class="px-5 py-3.5 text-zinc-500 dark:text-zinc-400">{emp.department || "—"}</td>
                <td class="px-5 py-3.5">
                  <span class="inline-flex items-center rounded-full bg-red-50 px-2.5 py-0.5 text-xs font-medium text-red-600 dark:bg-red-900/30 dark:text-red-400">
                    Absent
                  </span>
                </td>
              </tr>
              <tr :if={@absent_records == []}>
                <td colspan="4" class="px-5 py-12 text-center">
                  <div class="mx-auto flex max-w-sm flex-col items-center gap-2">
                    <.icon
                      name="hero-check-circle"
                      class="size-8 text-emerald-500 dark:text-emerald-400"
                    />
                    <p class="text-sm font-medium text-emerald-600 dark:text-emerald-400">
                      100% attendance recorded on this date
                    </p>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <%!-- Range summary --%>
      <div
        :if={@active_tab == :summary}
        class="mt-6 overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-xs dark:border-zinc-800 dark:bg-zinc-900"
      >
        <div class="border-b border-zinc-200 px-5 py-4 text-sm dark:border-zinc-800">
          <span class="text-zinc-500 dark:text-zinc-400">
            {length(@summary_records)} active workers,
            <span class="font-medium text-zinc-900 dark:text-zinc-100">
              {Calendar.strftime(@start_date, "%d %b")} – {Calendar.strftime(@end_date, "%d %b %Y")}
            </span>
          </span>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm text-left text-zinc-900 dark:text-zinc-100">
            <thead>
              <tr class="border-b border-zinc-200 bg-zinc-50 text-xs font-medium uppercase tracking-wider text-zinc-500 dark:border-zinc-800 dark:bg-zinc-800/60 dark:text-zinc-400">
                <th class="px-5 py-3">Code</th>
                <th class="px-5 py-3">Employee</th>
                <th class="px-5 py-3">Department</th>
                <th class="px-5 py-3 text-center">Days present</th>
                <th class="px-5 py-3 text-center">Missing clock-outs</th>
                <th class="px-5 py-3 text-right">Total hours</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-zinc-200 dark:divide-zinc-800">
              <tr
                :for={row <- @summary_records}
                class="transition-colors hover:bg-zinc-50 dark:hover:bg-zinc-800/50"
              >
                <td class="px-5 py-3.5 font-medium tabular-nums">{row.emp_code}</td>
                <td class="px-5 py-3.5 font-medium">{row.name}</td>
                <td class="px-5 py-3.5 text-zinc-500 dark:text-zinc-400">{row.department || "—"}</td>
                <td class="px-5 py-3.5 text-center tabular-nums">{row.days_present}</td>
                <td class="px-5 py-3.5 text-center tabular-nums">
                  <span class={
                    if row.shifts_missing_clock_out > 0,
                      do: "font-semibold text-amber-600 dark:text-amber-400",
                      else: "text-zinc-400 dark:text-zinc-500"
                  }>
                    {row.shifts_missing_clock_out}
                  </span>
                </td>
                <td class="px-5 py-3.5 text-right font-semibold tabular-nums">
                  {row.total_hours} hrs
                </td>
              </tr>
              <tr :if={@summary_records == []}>
                <td colspan="6" class="px-5 py-12 text-center text-zinc-400 dark:text-zinc-500">
                  No attendance records found within this date range.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-medium",
      @status == :normal &&
        "bg-emerald-50 text-emerald-600 dark:bg-emerald-900/30 dark:text-emerald-400",
      @status == :multiple_punches &&
        "bg-blue-50 text-blue-600 dark:bg-blue-900/30 dark:text-blue-400",
      @status == :duplicate_checkin_no_checkout &&
        "bg-amber-50 text-amber-600 dark:bg-amber-900/30 dark:text-amber-400",
      @status == :single_punch &&
        "bg-red-50 text-red-600 dark:bg-red-900/30 dark:text-red-400"
    ]}>
      {case @status do
        :normal -> "OK"
        :multiple_punches -> "Multiple punches"
        :duplicate_checkin_no_checkout -> "Double-tap"
        :single_punch -> "Missing exit"
      end}
    </span>
    """
  end
end
