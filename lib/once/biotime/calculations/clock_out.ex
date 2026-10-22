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

    adj = Once.Time.punch_adjustment_seconds()
    tz = Once.Time.timezone_offset_seconds()

    # Logical-day window (same as ClockIn); the outer query then requires the
    # punch to be at least 15 minutes after the day's first punch, so the
    # clock-out is never a double-tap of the clock-in.
    Ash.Expr.expr(
      fragment(
        """
        (
          SELECT (p.punch_time - make_interval(secs => ?))::timestamp
          FROM biotime_punches p
          WHERE p.emp_code = ?
            AND p.punch_time >= (COALESCE(?, (CURRENT_TIMESTAMP + make_interval(secs => ?))::date)::timestamp + make_interval(secs => ?))
            AND p.punch_time < (COALESCE(?, (CURRENT_TIMESTAMP + make_interval(secs => ?))::date)::timestamp + INTERVAL '1 day' + make_interval(secs => ?))
            AND p.punch_time >= (
              SELECT MIN(p2.punch_time) + INTERVAL '15 minutes'
              FROM biotime_punches p2
              WHERE p2.emp_code = ?
                AND p2.punch_time >= (COALESCE(?, (CURRENT_TIMESTAMP + make_interval(secs => ?))::date)::timestamp + make_interval(secs => ?))
                AND p2.punch_time < (COALESCE(?, (CURRENT_TIMESTAMP + make_interval(secs => ?))::date)::timestamp + INTERVAL '1 day' + make_interval(secs => ?))
            )
          ORDER BY p.punch_time DESC
          LIMIT 1
        )
        """,
        type(^adj, :integer),
        emp_code,
        type(^start_date, :date),
        type(^tz, :integer),
        type(^adj, :integer),
        type(^end_date, :date),
        type(^tz, :integer),
        type(^adj, :integer),
        emp_code,
        type(^start_date, :date),
        type(^tz, :integer),
        type(^adj, :integer),
        type(^end_date, :date),
        type(^tz, :integer),
        type(^adj, :integer)
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
