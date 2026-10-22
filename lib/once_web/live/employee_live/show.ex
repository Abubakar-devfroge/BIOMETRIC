defmodule OnceWeb.EmployeeLive.Show do
  use OnceWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header subtitle="Employee record synced from BioTime.">
        {if(@employee.first_name, do: @employee.first_name, else: "Employee")}
        {@employee.emp_code}

        <:actions>
          <.button navigate={~p"/employees"}>
            <.icon name="hero-arrow-left" class="size-4" /> Back
          </.button>
          <.button variant="primary" navigate={~p"/employees/#{@employee}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" class="size-4" /> Edit employee
          </.button>
        </:actions>
      </.header>

      <div class="max-w-2xl">
        <.list>
          <:item title="First name">{@employee.first_name || "—"}</:item>
          <:item title="Last name">{@employee.last_name || "—"}</:item>
          <:item title="Department">{@employee.department_name || "—"}</:item>
          <:item title="Area">{@employee.area_name || "—"}</:item>
          <:item title="Attendance tracking">
            {if @employee.enable_att, do: "Enabled", else: "Disabled"}
          </:item>
        </.list>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Employee")
     |> assign(:employee, Ash.get!(Once.Biotime.Employee, id))}
  end
end
