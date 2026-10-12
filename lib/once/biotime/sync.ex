defmodule Once.Biotime.Sync do
  @moduledoc """
  Ingests employees and attendance transactions from BioTime Cloud into local PostgreSQL.
  """

  require Logger
  alias Once.Biotime.{Client, Employee, Punch}

  @doc """
  Delta sync: queries the most recent punch timestamp in Postgres and fetches
  only transactions newer than that timestamp.
  This is the lightweight function executed by Oban every 15 minutes.
  """
  def sync_recent do
    with {:ok, token} <- Client.authenticate() do
      latest_punch =
        Punch
        |> Ash.Query.sort(punch_time: :desc)
        |> Ash.Query.limit(1)
        |> Ash.read_one!()

      start_time_str =
        case latest_punch do
          nil ->
            "2026-01-01 00:00:00"

          punch ->
            # Look back 2 hours to safely capture delayed uploads or device sync lags
            punch.punch_time
            |> NaiveDateTime.add(-7200, :second)
            |> NaiveDateTime.to_string()
            |> String.replace("T", " ")
        end

      {:ok, count} = sync_all_punches(token, %{"start_time" => start_time_str})
      Logger.info("BioTime delta sync completed: #{count} recent punches checked/updated.")
      {:ok, count}
    end
  end

  @doc """
  Runs full sync: all employees first, then paginates through all historical punches.
  """
  def sync_all(extra_params \\ %{}) do
    with {:ok, token} <- Client.authenticate(),
         {:ok, emp_count} <- sync_employees(token),
         {:ok, punch_count} <- sync_all_punches(token, extra_params) do
      Logger.info(
        "BioTime full sync finished: #{emp_count} employees, #{punch_count} punches processed."
      )

      {:ok, %{employees: emp_count, punches: punch_count}}
    end
  end

  @doc """
  Syncs all employees (page_size: 500 covers all 142 in one request).
  """
  def sync_employees(token, params \\ %{page_size: 500}) do
    with {:ok, %{"data" => employees}} <- Client.list_employees(token, params) do
      Enum.each(employees, fn emp ->
        area = List.first(emp["area"] || [])

        params = %{
          emp_code: to_string(emp["emp_code"]),
          first_name: emp["first_name"],
          last_name: emp["last_name"],
          department_name: get_in(emp, ["department", "dept_name"]),
          area_name: if(area, do: area["area_name"], else: nil),
          biotime_id: emp["id"],
          enable_att: if(is_nil(emp["enable_att"]), do: true, else: emp["enable_att"])
        }

        Employee
        |> Ash.Changeset.for_create(:upsert, params)
        |> Ash.create!()
      end)

      {:ok, length(employees)}
    end
  end

  @doc """
  Paginates through transactions until matching punches are ingested into Postgres.
  """
  def sync_all_punches(token, base_params \\ %{}, page_size \\ 500) do
    do_sync_punches_paged(token, base_params, 1, page_size, 0)
  end

  defp do_sync_punches_paged(token, base_params, page, page_size, total_accumulated) do
    params = Map.merge(base_params, %{page: page, page_size: page_size})

    case Client.list_transactions(token, params) do
      {:ok, %{"data" => []}} ->
        {:ok, total_accumulated}

      {:ok, %{"data" => punches}} ->
        batch_count = length(punches)

        Enum.each(punches, fn p ->
          {:ok, dt} = NaiveDateTime.from_iso8601(String.replace(p["punch_time"], " ", "T"))

          punch_params = %{
            biotime_id: p["id"],
            emp_code: to_string(p["emp_code"]),
            punch_time: dt,
            punch_state: to_string(p["punch_state"]),
            verify_type: p["verify_type"],
            terminal_sn: p["terminal_sn"],
            area_alias: p["area_alias"]
          }

          Punch
          |> Ash.Changeset.for_create(:upsert, punch_params)
          |> Ash.create!()
        end)

        if batch_count < page_size do
          {:ok, total_accumulated + batch_count}
        else
          do_sync_punches_paged(
            token,
            base_params,
            page + 1,
            page_size,
            total_accumulated + batch_count
          )
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
