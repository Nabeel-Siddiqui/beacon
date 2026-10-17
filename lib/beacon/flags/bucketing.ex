defmodule Beacon.Flags.Bucketing do
  @moduledoc """
  Decides whether one subject falls inside a flag's rollout percentage.
  Deterministic, not random: the same flag and subject must always get
  the same answer, or a user would flicker between "has the feature" and
  "doesn't" on every request.
  """

  @doc """
  Whether `subject_id` falls inside `percentage` of `flag_key`'s
  rollout. Hashes the pair into a bucket 0-99, so the same subject
  always lands in the same bucket for a given flag, and different flags
  bucket the same subject independently (someone in the first 10% of
  flag A isn't necessarily in the first 10% of flag B).
  """
  @spec in_rollout?(String.t(), String.t(), 0..100) :: boolean()
  def in_rollout?(flag_key, subject_id, percentage)
      when is_binary(flag_key) and is_binary(subject_id) and percentage in 0..100 do
    bucket = :erlang.phash2({flag_key, subject_id}, 100)
    bucket < percentage
  end
end
