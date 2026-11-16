defmodule Beacon.Flags.ExpireFlagsWorker do
  @moduledoc """
  Cron job (via `Oban.Plugins.Cron`, every 5 minutes) that disables any
  flag state whose `expires_at` has passed. See
  `Flags.expire_due_flag_states/0`, which this just calls, and
  [ADR 5](../../../docs/decisions/0005-flag-expiry-is-a-cron-sweep.md)
  for why a periodic sweep rather than scheduling an exact-time job per
  expiry.
  """

  use Oban.Worker, queue: :maintenance

  alias Beacon.Flags

  @impl Oban.Worker
  def perform(_job) do
    :ok = Flags.expire_due_flag_states()
    :ok
  end
end
