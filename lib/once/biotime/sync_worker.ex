defmodule Once.Biotime.SyncWorker do
  @moduledoc """
  Background worker scheduled via Oban to ingest punch logs and employee
  records from BioTime Cloud.
  """

  use Oban.Worker,
    queue: :biotime,
    max_attempts: 3,
    tags: ["biotime", "attendance", "sync"]

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, attempt: attempt}) do
    Logger.info("Starting BioTime sync worker (attempt #{attempt}, args: #{inspect(args)})...")

    sync_result =
      cond do
        Map.get(args, "full") == true or Map.get(args, "full_sync") == true ->
          if function_exported?(Once.Biotime.Sync, :sync_all, 0) do
            Once.Biotime.Sync.sync_all()
          else
            Once.Biotime.Sync.sync_recent()
          end

        true ->
          Once.Biotime.Sync.sync_recent()
      end

    case sync_result do
      {:ok, count} ->
        Logger.info("BioTime background sync succeeded: #{inspect(count)} records processed.")
        :ok

      {:ok, employees, punches} ->
        Logger.info(
          "BioTime sync succeeded: #{inspect(employees)} employees, #{inspect(punches)} punches processed."
        )

        :ok

      {:error, reason} ->
        Logger.error("BioTime background sync failed: #{inspect(reason)}")
        {:error, reason}

      other ->
        Logger.info("BioTime background sync completed with return value: #{inspect(other)}")
        :ok
    end
  rescue
    e ->
      Logger.error(
        "BioTime sync worker encountered unhandled exception: #{Exception.format(:error, e, __STACKTRACE__)}"
      )

      reraise e, __STACKTRACE__
  end
end
