defmodule Once.Biotime.Reports do
  @moduledoc """
  Generates attendance, absence, and hours-worked reports using local Ash resources,
  with debounce filtering for accidental double-punches and multiple erratic terminal taps.
  """

  require Ash.Query
  alias Once.Biotime.{Employee, Punch}

  # Minimum gap (in minutes) between first and last punch to be counted as a legitimate shift.
  # Anything less is treated as duplicate arrival punches (double-tap), NOT an exit clock-out.
  @min_shift_minutes 15

  @doc """
  Builds daily sessions for each employee across a date range.
  Filters double-taps and resolves true clock-in and clock-out timestamps.
  """
  def daily_attendance(start_date, end_date \\ nil)

  def daily_attendance(start_date, end_date) do
    {start_dt, end_dt} = Once.Time.date_range_bounds(start_date, end_date)

    Punch
    |> Ash.Query.filter(punch_time >= ^start_dt and punch_time <= ^end_dt)
    |> Ash.Query.load(:employee)
    |> Ash.read!()
    # Normalize every punch to *reported* time (terminal drift correction)
    |> Enum.map(fn p -> %{p | punch_time: Once.Time.to_reported(p.punch_time)} end)
    |> Enum.group_by(fn p -> {p.emp_code, NaiveDateTime.to_date(p.punch_time)} end)
    |> Enum.map(fn {{emp_code, date}, day_punches} ->
      sorted_punches = Enum.sort_by(day_punches, & &1.punch_time, NaiveDateTime)
      sorted_times = Enum.map(sorted_punches, & &1.punch_time)
      emp = List.first(sorted_punches).employee

      shift = resolve_daily_shift(sorted_times)

      Map.merge(shift, %{
        emp_code: emp_code,
        name: if(emp, do: emp.first_name, else: "Code #{emp_code}"),
        department: if(emp, do: emp.department_name),
        date: date,
        total_punches: length(sorted_times),
        all_punch_times: sorted_times
      })
    end)
    |> Enum.sort_by(& &1.clock_in, {:desc, NaiveDateTime})
  end

  @doc """
  Employees who punched in on a target date but never logged an exit punch
  (including employees who punched 2+ times within a few minutes of arriving).
  """
  def clocked_in_no_clock_out(target_date) do
    daily_attendance(target_date, target_date)
    |> Enum.filter(& &1.missing_clock_out?)
  end

  @doc """
  Employees active for attendance tracking (`enable_att: true`) who have zero punches on `target_date`.
  """
  def absent_on_date(target_date) do
    {start_dt, end_dt} = Once.Time.date_range_bounds(target_date)

    present_codes =
      Punch
      |> Ash.Query.filter(punch_time >= ^start_dt and punch_time <= ^end_dt)
      |> Ash.read!()
      |> Enum.map(& &1.emp_code)
      |> MapSet.new()

    Employee
    |> Ash.Query.filter(enable_att == true)
    |> Ash.read!()
    |> Enum.reject(fn emp -> MapSet.member?(present_codes, emp.emp_code) end)
    |> Enum.map(fn emp ->
      %{
        emp_code: emp.emp_code,
        name: emp.first_name,
        department: emp.department_name,
        date: target_date
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Total hours worked and days attended per employee across a date range.
  """
  def hours_summary(start_date, end_date) do
    daily_attendance(start_date, end_date)
    |> Enum.group_by(& &1.emp_code)
    |> Enum.map(fn {emp_code, records} ->
      first = hd(records)
      total_hours = records |> Enum.map(& &1.hours_worked) |> Enum.sum() |> Float.round(2)

      %{
        emp_code: emp_code,
        name: first.name,
        department: first.department,
        total_hours: total_hours,
        days_present: length(records),
        shifts_missing_clock_out: Enum.count(records, & &1.missing_clock_out?)
      }
    end)
    |> Enum.sort_by(& &1.total_hours, :desc)
  end

  @doc """
  Employees who never logged a single punch across an entire calendar month or date range.
  """
  def inactive_employees(start_date, end_date) do
    {start_dt, end_dt} = Once.Time.date_range_bounds(start_date, end_date)

    active_codes =
      Punch
      |> Ash.Query.filter(punch_time >= ^start_dt and punch_time <= ^end_dt)
      |> Ash.read!()
      |> Enum.map(& &1.emp_code)
      |> MapSet.new()

    Employee
    |> Ash.Query.filter(enable_att == true)
    |> Ash.read!()
    |> Enum.reject(fn emp -> MapSet.member?(active_codes, emp.emp_code) end)
    |> Enum.map(fn emp ->
      %{
        emp_code: emp.emp_code,
        name: emp.first_name,
        department: emp.department_name
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  # --- Internal Helpers ---

  defp resolve_daily_shift(sorted_punch_times) do
    clock_in = List.first(sorted_punch_times)
    last_punch = List.last(sorted_punch_times)
    minutes_diff = NaiveDateTime.diff(last_punch, clock_in, :minute)

    cond do
      # Exactly 1 punch all day
      length(sorted_punch_times) == 1 ->
        %{
          clock_in: clock_in,
          clock_out: nil,
          hours_worked: 0.0,
          missing_clock_out?: true,
          status: :single_punch
        }

      # Multiple punches, but all occurred within @min_shift_minutes (double-tap/hesitation)
      minutes_diff < @min_shift_minutes ->
        %{
          clock_in: clock_in,
          clock_out: nil,
          hours_worked: 0.0,
          missing_clock_out?: true,
          status: :duplicate_checkin_no_checkout
        }

      # Valid shift: first punch = In, last punch = Out
      true ->
        hours = Float.round(NaiveDateTime.diff(last_punch, clock_in, :second) / 3600, 2)

        %{
          clock_in: clock_in,
          clock_out: last_punch,
          hours_worked: hours,
          missing_clock_out?: false,
          status: if(length(sorted_punch_times) > 2, do: :multiple_punches, else: :normal)
        }
    end
  end
end
