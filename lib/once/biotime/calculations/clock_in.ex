defmodule Once.Biotime.Calculations.ClockIn do
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

    # Logical-day window: a punch belongs to day D when
    #   report(punch) = punch - adj  falls in [D 00:00, D 23:59:59]
    # i.e. by raw time: [D + adj, D + 1 day + adj).
    Ash.Expr.expr(
      fragment(
        """
        (
          SELECT (p.punch_time - make_interval(secs => ?))::timestamp
          FROM biotime_punches p
          WHERE p.emp_code = ?
            AND p.punch_time >= (COALESCE(?, (CURRENT_TIMESTAMP + make_interval(secs => ?))::date)::timestamp + make_interval(secs => ?))
            AND p.punch_time < (COALESCE(?, (CURRENT_TIMESTAMP + make_interval(secs => ?))::date)::timestamp + INTERVAL '1 day' + make_interval(secs => ?))
          ORDER BY p.punch_time ASC
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
