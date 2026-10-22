defmodule OnceWeb.AttendanceLive do
  use OnceWeb, :live_view

  alias Once.Biotime.{Reports, Sync}

  @impl true
  def mount(_params, _session, socket) do
    today = Once.Time.nairobi_today()

    socket =
      socket
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
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
      <%!-- Top Action Header --%>
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between pb-4 border-b border-zinc-200">
        <div>
          <h1 class="text-2xl font-bold tracking-tight text-zinc-900 font-mono">
            ATTENDANCE // BIOTIME
          </h1>
          <p class="text-xs text-zinc-500 mt-1 uppercase tracking-wider">
            Real-time biometric logs & payroll aggregates
          </p>
        </div>

        <div class="mt-4 sm:mt-0 flex items-center gap-3">
          <button
            phx-click="trigger_sync"
            disabled={@syncing?}
            class="inline-flex items-center gap-2 px-3.5 py-1.5 text-xs font-semibold uppercase tracking-wider text-white bg-zinc-900 hover:bg-zinc-800 disabled:opacity-50 transition border border-zinc-900"
          >
            <span :if={@syncing?} class="animate-spin text-sm">⟳</span>
            {if @syncing?, do: "Syncing...", else: "Pull Sync Now"}
          </button>
        </div>
      </div>

      <%!-- Navigation Tabs & Controls --%>
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-zinc-50 p-2.5 border border-zinc-200">
        <nav class="flex gap-1" aria-label="Tabs">
          <button
            phx-click="switch_tab"
            phx-value-tab="daily"
            class={[
              "px-3 py-1.5 text-xs font-semibold tracking-wide uppercase transition",
              if(@active_tab == :daily,
                do: "bg-white text-zinc-900 shadow-sm border border-zinc-200",
                else: "text-zinc-500 hover:text-zinc-900"
              )
            ]}
          >
            Daily Attendance
          </button>

          <button
            phx-click="switch_tab"
            phx-value-tab="absent"
            class={[
              "px-3 py-1.5 text-xs font-semibold tracking-wide uppercase transition",
              if(@active_tab == :absent,
                do: "bg-white text-zinc-900 shadow-sm border border-zinc-200",
                else: "text-zinc-500 hover:text-zinc-900"
              )
            ]}
          >
            Absentees
          </button>

          <button
            phx-click="switch_tab"
            phx-value-tab="summary"
            class={[
              "px-3 py-1.5 text-xs font-semibold tracking-wide uppercase transition",
              if(@active_tab == :summary,
                do: "bg-white text-zinc-900 shadow-sm border border-zinc-200",
                else: "text-zinc-500 hover:text-zinc-900"
              )
            ]}
          >
            Monthly / Range Summary
          </button>
        </nav>

        <%!-- Contextual Filters --%>
        <div class="flex items-center gap-2 text-xs">
          <%= if @active_tab in [:daily, :absent] do %>
            <form phx-change="change_date" class="flex items-center gap-2">
              <label for="date-select" class="text-zinc-500 uppercase font-mono">Date:</label>
              <input
                id="date-select"
                type="date"
                name="date"
                value={Date.to_iso8601(@target_date)}
                class="px-2 py-1 text-xs border border-zinc-300 font-mono bg-white focus:outline-none focus:border-zinc-900"
              />
            </form>
          <% else %>
            <form phx-change="change_range" class="flex items-center gap-2">
              <label class="text-zinc-500 uppercase font-mono">From:</label>
              <input
                type="date"
                name="start_date"
                value={Date.to_iso8601(@start_date)}
                class="px-2 py-1 text-xs border border-zinc-300 font-mono bg-white focus:outline-none focus:border-zinc-900"
              />
              <label class="text-zinc-500 uppercase font-mono">To:</label>
              <input
                type="date"
                name="end_date"
                value={Date.to_iso8601(@end_date)}
                class="px-2 py-1 text-xs border border-zinc-300 font-mono bg-white focus:outline-none focus:border-zinc-900"
              />
            </form>
          <% end %>
        </div>
      </div>

      <%!-- Table View: Daily Attendance --%>
      <div :if={@active_tab == :daily} class="border border-zinc-200 bg-white">
        <div class="px-4 py-3 bg-zinc-50 border-b border-zinc-200 flex justify-between items-center text-xs">
          <span class="font-mono uppercase text-zinc-600">
            Records on {Calendar.strftime(@target_date, "%d %b %Y")}: {length(@daily_records)}
          </span>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-left text-xs font-mono">
            <thead class="bg-zinc-100 text-zinc-600 uppercase border-b border-zinc-200">
              <tr>
                <th class="px-4 py-2.5">Code</th>
                <th class="px-4 py-2.5">Employee</th>
                <th class="px-4 py-2.5">Dept</th>
                <th class="px-4 py-2.5">Clock In</th>
                <th class="px-4 py-2.5">Clock Out</th>
                <th class="px-4 py-2.5 text-right">Hours</th>
                <th class="px-4 py-2.5 text-center">Punches</th>
                <th class="px-4 py-2.5">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-zinc-200 text-zinc-800">
              <tr :for={row <- @daily_records} class="hover:bg-zinc-50 transition">
                <td class="px-4 py-2 font-bold text-zinc-900">{row.emp_code}</td>
                <td class="px-4 py-2 font-sans font-medium text-zinc-900">{row.name}</td>
                <td class="px-4 py-2 text-zinc-500">{row.department || "—"}</td>
                <td class="px-4 py-2">{Calendar.strftime(row.clock_in, "%H:%M:%S")}</td>
                <td class="px-4 py-2">
                  {if row.clock_out, do: Calendar.strftime(row.clock_out, "%H:%M:%S"), else: "—"}
                </td>
                <td class="px-4 py-2 text-right font-semibold">
                  {row.hours_worked}
                </td>
                <td class="px-4 py-2 text-center text-zinc-500">{row.total_punches}</td>
                <td class="px-4 py-2">
                  <span class={[
                    "px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider",
                    case row.status do
                      :normal ->
                        "bg-zinc-100 text-zinc-700"

                      :multiple_punches ->
                        "bg-blue-50 text-blue-700 border border-blue-200"

                      :duplicate_checkin_no_checkout ->
                        "bg-amber-50 text-amber-700 border border-amber-200"

                      :single_punch ->
                        "bg-rose-50 text-rose-700 border border-rose-200"
                    end
                  ]}>
                    {case row.status do
                      :normal -> "OK"
                      :multiple_punches -> "Multiple Hits"
                      :duplicate_checkin_no_checkout -> "Double-tap / Incomplete"
                      :single_punch -> "Missing Exit"
                    end}
                  </span>
                </td>
              </tr>
              <tr :if={@daily_records == []}>
                <td colspan="8" class="px-4 py-8 text-center text-zinc-400">
                  No attendance records logged for this date.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <%!-- Table View: Absentees --%>
      <div :if={@active_tab == :absent} class="border border-zinc-200 bg-white">
        <div class="px-4 py-3 bg-zinc-50 border-b border-zinc-200 flex justify-between items-center text-xs">
          <span class="font-mono uppercase text-zinc-600">
            Unrecorded Staff on {Calendar.strftime(@target_date, "%d %b %Y")}: {length(
              @absent_records
            )}
          </span>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-left text-xs font-mono">
            <thead class="bg-zinc-100 text-zinc-600 uppercase border-b border-zinc-200">
              <tr>
                <th class="px-4 py-2.5">Code</th>
                <th class="px-4 py-2.5">Employee Name</th>
                <th class="px-4 py-2.5">Department</th>
                <th class="px-4 py-2.5">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-zinc-200 text-zinc-800">
              <tr :for={emp <- @absent_records} class="hover:bg-zinc-50 transition">
                <td class="px-4 py-2 font-bold text-zinc-900">{emp.emp_code}</td>
                <td class="px-4 py-2 font-sans font-medium text-zinc-900">{emp.name}</td>
                <td class="px-4 py-2 text-zinc-500">{emp.department || "—"}</td>
                <td class="px-4 py-2">
                  <span class="px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider bg-rose-50 text-rose-700 border border-rose-200">
                    Absent / Zero Punches
                  </span>
                </td>
              </tr>
              <tr :if={@absent_records == []}>
                <td colspan="4" class="px-4 py-8 text-center text-emerald-600">
                  100% Attendance recorded on this date.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <%!-- Table View: Summary / Payroll --%>
      <div :if={@active_tab == :summary} class="border border-zinc-200 bg-white">
        <div class="px-4 py-3 bg-zinc-50 border-b border-zinc-200 flex justify-between items-center text-xs">
          <span class="font-mono uppercase text-zinc-600">
            Range: {Calendar.strftime(@start_date, "%d %b %Y")} — {Calendar.strftime(
              @end_date,
              "%d %b %Y"
            )} ({length(@summary_records)} Active Workers)
          </span>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-left text-xs font-mono">
            <thead class="bg-zinc-100 text-zinc-600 uppercase border-b border-zinc-200">
              <tr>
                <th class="px-4 py-2.5">Code</th>
                <th class="px-4 py-2.5">Employee</th>
                <th class="px-4 py-2.5">Department</th>
                <th class="px-4 py-2.5 text-center">Days Present</th>
                <th class="px-4 py-2.5 text-center">Missing Clock-Outs</th>
                <th class="px-4 py-2.5 text-right">Total Hours</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-zinc-200 text-zinc-800">
              <tr :for={row <- @summary_records} class="hover:bg-zinc-50 transition">
                <td class="px-4 py-2 font-bold text-zinc-900">{row.emp_code}</td>
                <td class="px-4 py-2 font-sans font-medium text-zinc-900">{row.name}</td>
                <td class="px-4 py-2 text-zinc-500">{row.department || "—"}</td>
                <td class="px-4 py-2 text-center">{row.days_present}</td>
                <td class="px-4 py-2 text-center">
                  <span class={
                    if row.shifts_missing_clock_out > 0,
                      do: "text-amber-600 font-bold",
                      else: "text-zinc-400"
                  }>
                    {row.shifts_missing_clock_out}
                  </span>
                </td>
                <td class="px-4 py-2 text-right font-bold text-zinc-900">{row.total_hours} hrs</td>
              </tr>
              <tr :if={@summary_records == []}>
                <td colspan="6" class="px-4 py-8 text-center text-zinc-400">
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
end
