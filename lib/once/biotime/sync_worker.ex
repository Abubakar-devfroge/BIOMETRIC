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
      if Map.get(args, "full") == true or Map.get(args, "full_sync") == true,
        do: Once.Biotime.Sync.sync_all(),
        else: Once.Biotime.Sync.sync_recent()

    case sync_result do
      {:ok, %{employees: employees, punches: punches}} ->
        Logger.info("BioTime full sync succeeded: #{employees} employees, #{punches} punches.")
        :ok

      {:ok, count} ->
        Logger.info("BioTime background sync succeeded: #{count} records processed.")
        :ok

      {:error, reason} ->
        Logger.error("BioTime background sync failed: #{inspect(reason)}")
        {:error, reason}

      other ->
        Logger.error("BioTime sync worker got unexpected return value: #{inspect(other)}")
        {:error, {:unexpected_result, other}}
    end
  rescue
    e ->
      Logger.error(
        "BioTime sync worker encountered unhandled exception: #{Exception.format(:error, e, __STACKTRACE__)}"
      )

      reraise e, __STACKTRACE__
  end
end
