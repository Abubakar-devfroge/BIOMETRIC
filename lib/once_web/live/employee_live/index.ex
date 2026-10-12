defmodule OnceWeb.EmployeeLive.Index do
  use OnceWeb, :live_view
  require Ash.Query

  @page_size 15

  @impl true
  def mount(_params, _session, socket) do
    today_iso =
      DateTime.utc_now()
      |> DateTime.add(3 * 3600, :second)
      |> DateTime.to_date()
      |> Date.to_iso8601()

    {:ok,
     socket
     |> assign(:page_title, "Employees")
     |> assign(:search_query, "")
     |> assign(:start_date, today_iso)
     |> assign(:end_date, today_iso)
     |> assign(:filter_shift, "all")
     |> assign(:page, 1)
     |> assign(:page_size, @page_size)
     |> load_employees()}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:page, 1)
     |> load_employees()}
  end

  @impl true
  def handle_event("filter_change", params, socket) do
    start_date = Map.get(params, "start_date", socket.assigns.start_date)
    end_date = Map.get(params, "end_date", socket.assigns.end_date)
    shift = Map.get(params, "shift", socket.assigns.filter_shift)

    {:noreply,
     socket
     |> assign(:start_date, start_date)
     |> assign(:end_date, end_date)
     |> assign(:filter_shift, shift)
     |> assign(:page, 1)
     |> load_employees()}
  end

  @impl true
  def handle_event("goto_page", %{"page" => page_str}, socket) do
    page = String.to_integer(page_str)
    {:noreply, socket |> assign(:page, page) |> load_employees()}
  end

  defp load_employees(socket) do
    query = socket.assigns.search_query
    shift = socket.assigns.filter_shift
    page = socket.assigns.page
    page_size = socket.assigns.page_size

    start_date = parse_date(socket.assigns.start_date)
    end_date = parse_date(socket.assigns.end_date)

    calc_args = %{
      start_date: start_date,
      end_date: end_date
    }

    base_query =
      Once.Biotime.Employee
      |> Ash.Query.set_context(calc_args)
      |> Ash.Query.load([
        :full_name,
        {:today_clock_in, calc_args},
        {:today_clock_out, calc_args}
      ])

    # 1. Text search at DB layer
    filtered_query =
      case String.trim(query) do
        "" ->
          base_query

        search_term ->
          pattern = "%#{search_term}%"

          Ash.Query.filter(
            base_query,
            ilike(first_name, ^pattern) or
              ilike(last_name, ^pattern) or
              ilike(emp_code, ^pattern) or
              ilike(department_name, ^pattern)
          )
      end

    # 2. Single-pass read (evaluates today_clock_in & clock_out once per row)
    all_employees = Ash.read!(filtered_query)

    # 3. Shift status filter in memory to prevent SQL subquery duplication
    matching_employees =
      case shift do
        "present" ->
          Enum.filter(all_employees, &(&1.today_clock_in != nil))

        "in_building" ->
          Enum.filter(all_employees, fn emp ->
            emp.today_clock_in != nil and
              (is_nil(emp.today_clock_out) or emp.today_clock_in == emp.today_clock_out)
          end)

        "completed" ->
          Enum.filter(all_employees, fn emp ->
            emp.today_clock_in != nil and
              not is_nil(emp.today_clock_out) and
              emp.today_clock_in != emp.today_clock_out
          end)

        "absent" ->
          Enum.filter(all_employees, &is_nil(&1.today_clock_in))

        _ ->
          all_employees
      end

    # 4. Sort: Clocked-in first (descending), then emp_code ascending
    sorted_employees =
      Enum.sort_by(
        matching_employees,
        fn emp ->
          {emp.today_clock_in == nil, emp.today_clock_in, emp.emp_code}
        end,
        fn {nil_a, time_a, code_a}, {nil_b, time_b, code_b} ->
          cond do
            nil_a != nil_b ->
              not nil_a

            time_a != nil and time_b != nil and time_a != time_b ->
              NaiveDateTime.compare(time_a, time_b) == :gt

            true ->
              code_a <= code_b
          end
        end
      )

    # 5. In-memory pagination
    total_count = length(sorted_employees)
    total_pages = max(1, ceil(total_count / page_size))
    offset = (page - 1) * page_size

    paged_employees =
      sorted_employees
      |> Enum.drop(offset)
      |> Enum.take(page_size)

    socket
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
    |> stream(:employees, paged_employees, reset: true)
  end

  defp parse_date(date_str) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_date(_), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <.header>
          {@page_title}
        </.header>

        <div>
          <div class="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
            <form phx-change="search" phx-submit="search" class="w-full lg:max-w-md">
              <div class="relative">
                <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3.5 text-zinc-400">
                  <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                    />
                  </svg>
                </div>
                <.input
                  type="text"
                  name="query"
                  value={@search_query}
                  placeholder="Search by code, employee name, department..."
                  phx-debounce="150"
                />
              </div>
            </form>

            <form phx-change="filter_change" class="flex flex-wrap items-center gap-2.5">
              <div class="flex items-center gap-1.5 rounded-lg px-2.5 py-1.5">
                <span class="text-xs font-medium uppercase tracking-wider text-zinc-400">From</span>
                <.input
                  type="date"
                  name="start_date"
                  value={@start_date}
                />
                <span class="text-xs font-medium uppercase tracking-wider text-zinc-400">To</span>
                <.input
                  type="date"
                  name="end_date"
                  value={@end_date}
                />
              </div>

              <select
                name="shift"
                class="py-2 pl-3 pr-8 text-sm font-medium text-zinc-800 focus:border-zinc-500 focus:outline-none focus:ring-1 focus:ring-zinc-500 dark:text-zinc-200"
              >
                <option value="all" selected={@filter_shift == "all"}>All Statuses</option>
                <option value="present" selected={@filter_shift == "present"}>Present</option>
                <option value="in_building" selected={@filter_shift == "in_building"}>
                  In Building
                </option>
                <option value="completed" selected={@filter_shift == "completed"}>Completed</option>
                <option value="absent" selected={@filter_shift == "absent"}>Absent</option>
              </select>
            </form>
          </div>
        </div>

        <.table
          id="employees"
          rows={@streams.employees}
          row_click={fn {_id, employee} -> JS.navigate(~p"/employees/#{employee}") end}
        >
          <:col :let={{_id, employee}} label="Code">
            {employee.emp_code}
          </:col>

          <:col :let={{_id, employee}} label="Name">
            <div>{employee.full_name}</div>
            <span :if={!employee.enable_att} class="text-xs font-semibold text-rose-500">
              Attendance Disabled
            </span>
          </:col>

          <:col :let={{_id, employee}} label="Department">
            {employee.department_name || "—"}
          </:col>

          <:col :let={{_id, employee}} label="Clock In">
            {if employee.today_clock_in,
              do: Calendar.strftime(employee.today_clock_in, "%I:%M:%S %p"),
              else: "—"}
          </:col>

          <:col :let={{_id, employee}} label="Clock Out">
            {if employee.today_clock_out && employee.today_clock_out != employee.today_clock_in,
              do: Calendar.strftime(employee.today_clock_out, "%I:%M:%S %p"),
              else: "—"}
          </:col>
        </.table>

        <div :if={@total_pages > 1} class="flex items-center justify-center gap-1.5 py-4">
          <button
            :for={p <- 1..@total_pages}
            type="button"
            phx-click="goto_page"
            phx-value-page={p}
            class={[
              "btn btn-sm min-w-8",
              if(p == @page, do: "btn-primary", else: "btn-ghost")
            ]}
          >
            {p}
          </button>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
