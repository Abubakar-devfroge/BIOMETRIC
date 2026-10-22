defmodule Once.Time do
  @moduledoc """
  Single source of truth for time policy across Once.

  Background: punch data arrives as naive datetimes straight from BioTime
  terminals that are known to run slightly ahead of true time, and all storage
  is naive (no zone). Every part of the app that turns a punch into "day X at
  time Y" must go through this module so pages can never disagree about what
  "today" means or how a raw punch maps to a reported one.

  - `timezone_offset_seconds/0` — fixed EAT (UTC+3) offset used to compute
    Nairobi calendar dates and day boundaries from stored timestamps.
  - `punch_adjustment_seconds/0` — correction for terminal clock drift. Raw
    punch times are shifted *back* by this many seconds for reporting, and day
    windows shift *forward* by the same amount so logical days stay intact.
    Configurable via `BIOTIME_PUNCH_ADJUSTMENT_SECONDS`; default `8898`
    (2h 28m 18s, the previously-hardcoded device drift correction).
  """

  @timezone_offset_seconds 3 * 3600

  @doc "Fixed EAT offset (UTC+3) in seconds."
  def timezone_offset_seconds, do: @timezone_offset_seconds

  @doc """
  The calendar date a person in Nairobi would call "today", regardless of the
  server's configured timezone.
  """
  def nairobi_today do
    DateTime.utc_now()
    |> DateTime.add(@timezone_offset_seconds, :second)
    |> DateTime.to_date()
  end

  @doc """
  Terminal clock-drift correction in seconds. A punch delivered with the
  terminal's drifted clock is reported `punch_adjustment_seconds/0` earlier.
  """
  def punch_adjustment_seconds do
    Application.get_env(:once, :biotime, [])
    |> Keyword.get(:punch_adjustment_seconds, 8898)
  end

  @doc """
  Converts a raw (drifted) punch timestamp into the reported timestamp used by
  all pages and reports.
  """
  def to_reported(punch_time) when is_struct(punch_time, NaiveDateTime) do
    NaiveDateTime.add(punch_time, -punch_adjustment_seconds(), :second)
  end

  @doc """
  DB filter bounds for a logical date range. Raw punches falling between
  `start_date <= reported(punch) <= end_date` are the ones in range.
  """
  def date_range_bounds(start_date, end_date \\ nil)

  def date_range_bounds(start_date, end_date) do
    adj = punch_adjustment_seconds()
    end_date = end_date || start_date

    {
      NaiveDateTime.new!(start_date, ~T[00:00:00]) |> NaiveDateTime.add(adj, :second),
      NaiveDateTime.new!(end_date, ~T[23:59:59]) |> NaiveDateTime.add(adj, :second)
    }
  end
end
