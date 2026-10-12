defmodule Once.Biotime.Calculations.ClockOut do
  use Ash.Resource.Calculation

  @impl true
  def expression(_opts, context) do
    start_date =
      normalize_date(
        context.arguments[:start_date] || Map.get(context.source_context || %{}, :start_date)
      )

    end_date =
      normalize_date(
        context.arguments[:end_date] || Map.get(context.source_context || %{}, :end_date)
      )

    Ash.Expr.expr(
      fragment(
        """
        (
          SELECT (p.punch_time - INTERVAL '2 hours 28 minutes 18 seconds')::timestamp
          FROM biotime_punches p
          WHERE p.emp_code = ?
            AND p.punch_time >= (COALESCE(?, (CURRENT_TIMESTAMP + INTERVAL '3 hours')::date)::timestamp + INTERVAL '2 hours 28 minutes 18 seconds')
            AND p.punch_time < (COALESCE(?, (CURRENT_TIMESTAMP + INTERVAL '3 hours')::date)::timestamp + INTERVAL '1 day' + INTERVAL '2 hours 28 minutes 18 seconds')
            AND p.punch_time >= (
              SELECT MIN(p2.punch_time) + INTERVAL '15 minutes'
              FROM biotime_punches p2
              WHERE p2.emp_code = ?
                AND p2.punch_time >= (COALESCE(?, (CURRENT_TIMESTAMP + INTERVAL '3 hours')::date)::timestamp + INTERVAL '2 hours 28 minutes 18 seconds')
                AND p2.punch_time < (COALESCE(?, (CURRENT_TIMESTAMP + INTERVAL '3 hours')::date)::timestamp + INTERVAL '1 day' + INTERVAL '2 hours 28 minutes 18 seconds')
            )
          ORDER BY p.punch_time DESC
          LIMIT 1
        )
        """,
        emp_code,
        type(^start_date, :date),
        type(^end_date, :date),
        emp_code,
        type(^start_date, :date),
        type(^end_date, :date)
      )
    )
  end

  defp normalize_date(%Date{} = d), do: d

  defp normalize_date(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp normalize_date(_), do: nil
end
