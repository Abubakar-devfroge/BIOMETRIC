defmodule OnceWeb.EmployeeLive.Index do
  use OnceWeb, :live_view
  require Ash.Query

  @page_size 15

  @impl true
  def mount(_params, _session, socket) do
    today_iso =
      Once.Time.nairobi_today()
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
     |> assign(:syncing, false)
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

  @impl true
  def handle_event("sync_data", _params, socket) do
    send(self(), :run_delta_sync)
    {:noreply, assign(socket, :syncing, true)}
  end

  @impl true
  def handle_info(:run_delta_sync, socket) do
    case Once.Biotime.Sync.sync_recent() do
      {:ok, count} ->
        {:noreply,
         socket
         |> assign(:syncing, false)
         |> put_flash(:info, "Sync complete: #{count} records updated.")
         |> load_employees()}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:syncing, false)
         |> put_flash(:error, "Sync failed: #{inspect(reason)}")}
    end
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
end
