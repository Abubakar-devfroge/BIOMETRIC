defmodule OnceWeb.EmployeeLive.Form do
  use OnceWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage employee records in your database.</:subtitle>
      </.header>

      <.form
        for={@form}
        id="employee-form"
        phx-change="validate"
        phx-submit="save"
      >
        <%= if @form.source.type == :create do %>
          <.input field={@form[:emp_code]} type="text" label="Emp code" /><.input
            field={@form[:first_name]}
            type="text"
            label="First name"
          /><.input field={@form[:last_name]} type="text" label="Last name" /><.input
            field={@form[:department_name]}
            type="text"
            label="Department name"
          /><.input field={@form[:area_name]} type="text" label="Area name" /><.input
            field={@form[:biotime_id]}
            type="text"
            label="Biotime"
          /><.input field={@form[:enable_att]} type="checkbox" label="Enable att" />
        <% end %>
        <%= if @form.source.type == :update do %>
          <.input field={@form[:first_name]} type="text" label="First name" /><.input
            field={@form[:last_name]}
            type="text"
            label="Last name"
          /><.input field={@form[:department_name]} type="text" label="Department name" /><.input
            field={@form[:area_name]}
            type="text"
            label="Area name"
          /><.input field={@form[:enable_att]} type="checkbox" label="Enable att" />
        <% end %>

        <.button phx-disable-with="Saving..." variant="primary">Save Employee</.button>
        <.button navigate={return_path(@return_to, @employee)}>Cancel</.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    employee =
      case params["id"] do
        nil -> nil
        id -> Ash.get!(Once.Biotime.Employee, id)
      end

    action = if is_nil(employee), do: "New", else: "Edit"
    page_title = action <> " " <> "Employee"

    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> assign(employee: employee)
     |> assign(:page_title, page_title)
     |> assign_form()}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  @impl true
  def handle_event("validate", %{"employee" => employee_params}, socket) do
    {:noreply,
     assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, employee_params))}
  end

  def handle_event("save", %{"employee" => employee_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: employee_params) do
      {:ok, employee} ->
        socket =
          socket
          |> put_flash(:info, "Employee #{socket.assigns.form.source.type}d successfully")
          |> push_navigate(to: return_path(socket.assigns.return_to, employee))

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp assign_form(%{assigns: %{employee: employee}} = socket) do
    form =
      if employee do
        AshPhoenix.Form.for_update(employee, :update, as: "employee")
      else
        AshPhoenix.Form.for_create(Once.Biotime.Employee, :upsert, as: "employee")
      end

    assign(socket, form: to_form(form))
  end

  defp return_path("index", _employee), do: ~p"/employees"
  defp return_path("show", employee), do: ~p"/employees/#{employee.id}"
end
