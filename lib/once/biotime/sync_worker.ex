defmodule Once.Biotime.SyncWorker do
  @moduledoc """
  Background worker scheduled via Oban to ingest delta punches from BioTime Cloud.
  """

  use Oban.Worker,
    queue: :biotime,
    max_attempts: 3,
    tags: ["biotime", "attendance", "sync"]

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{attempt: attempt}) do
    Logger.info("Starting BioTime delta sync worker (attempt #{attempt})...")

    case Once.Biotime.Sync.sync_recent() do
      {:ok, count} ->
        Logger.info("BioTime background sync succeeded: #{count} records processed.")
        :ok

      {:error, reason} ->
        Logger.error("BioTime background sync failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
