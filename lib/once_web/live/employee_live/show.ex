defmodule OnceWeb.EmployeeLive.Show do
  use OnceWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Employee {@employee.id}
        <:subtitle>This is a employee record from your database.</:subtitle>

        <:actions>
          <.button navigate={~p"/employees"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/employees/#{@employee}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit Employee
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Id">{@employee.id}</:item>

        <:item title="Emp code">{@employee.emp_code}</:item>

        <:item title="First name">{@employee.first_name}</:item>

        <:item title="Department name">{@employee.department_name}</:item>

        <:item title="Area name">{@employee.area_name}</:item>
      </.list>
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
