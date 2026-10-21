# 2. Rollout percentages are deterministic, not random

## Status

Accepted (Phase 2).

## Context

A 25% rollout needs to decide, for a given subject (a user id, most
commonly), whether they're in the rolled-out group. The obvious-looking
approach — roll a random number on each evaluation — is wrong: it means
the same user gets a different answer on their next request, flickering
between having a feature and not having it within the same session.

## Decision

`Beacon.Flags.Bucketing.in_rollout?/3` hashes `{flag_key, subject_id}`
with `:erlang.phash2/2` into a bucket from 0 to 99, then compares it
against the rollout percentage. The same flag and subject always hash
to the same bucket, so the same subject always gets the same answer for
that flag, for as long as the percentage doesn't change. Different
flags bucket the same subject independently — being in the first 10% of
one flag's rollout says nothing about any other flag.

## Alternatives considered

- **`:rand.uniform/1` on each evaluation.** The straightforward reading
  of "25% of the time," and wrong for the reason above — it answers
  "25% of evaluations," not "25% of users," and those are different
  guarantees.
- **Store each subject's bucket assignment in the database.** Gives the
  same stability without relying on a hash function, but means writing
  a row the first time any subject is ever evaluated against any flag,
  turning a read-only evaluation into a write, and needing that write
  to happen before the read can even answer.
- **A cryptographic hash (SHA-256) instead of `:erlang.phash2/2`.**
  No actual benefit here — bucketing isn't a security boundary, nothing
  is at stake if someone could predict their own bucket, and
  `:erlang.phash2/2` is faster and already part of the standard library.

## Consequences

- A rollout percentage change takes effect for every subject
  immediately and consistently — nobody needs to wait for a "reroll."
- Two different flags rolling out to "the same" 25% would actually
  roll out to different, independent 25% subsets, since each flag's key
  is part of what's hashed. That's a deliberate property, not a bug:
  flags aren't meant to correlate with each other by default.
