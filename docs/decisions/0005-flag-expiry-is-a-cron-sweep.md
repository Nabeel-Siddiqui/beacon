# 5. Flag expiry is a 5-minute cron sweep, not a scheduled job per expiry

## Status

Accepted (flag expiry feature).

## Context

A flag meant for a short-lived experiment had to be turned off by
hand. Letting a flag's state carry an `expires_at` and disabling it
automatically needs something to actually notice the deadline has
passed. The two realistic shapes: schedule one job per expiry, timed
to fire at that exact moment (`Oban.insert/2` with `scheduled_at`), or
run a periodic sweep that checks "what's overdue right now" on a
fixed interval.

## Decision

`Beacon.Flags.ExpireFlagsWorker` runs on an `Oban.Plugins.Cron`
schedule, every 5 minutes, calling `Flags.expire_due_flag_states/0` —
one query for every `FlagState` whose `expires_at` has passed and is
still `enabled`, then one `set_flag_state/4` call per row. Disabling
happens through the exact same write path the dashboard itself uses
(the same `Ecto.Multi`, the same audit log entry), not a bypass.

## Alternatives considered

- **One scheduled Oban job per expiry**, inserted alongside the
  `FlagState` write and cancelled/rescheduled if the expiry changes.
  Fires at the exact moment, rather than up to 5 minutes late, but
  needs tracking which job belongs to which `FlagState` (to cancel a
  stale one when the expiry is changed or cleared) — real bookkeeping
  for a feature where "up to 5 minutes late" is an acceptable
  trade-off. A feature flag's expiry isn't a user-facing SLA; nobody
  is harmed by a flag staying on 4 minutes past its deadline.
- **Check `expires_at` at evaluation time instead** (`enabled?/4`
  treats an expired-but-still-`enabled` row as off, without ever
  writing a disable). Keeps evaluation fast (no extra write), but
  means Postgres and the audit log silently disagree with what the
  flag is actually doing — exactly the kind of drift
  [ADR 1](0001-postgres-source-of-truth-ets-cache.md) exists to rule
  out. The dashboard would show "on" for a flag that's actually
  behaving as off everywhere, with nothing in the audit log explaining
  why.

## Consequences

- An expiry fires within 5 minutes of its deadline, not at the exact
  second — acceptable slop for this feature, explicitly not for
  everything (see ADR 1's own standard for what Postgres vs. ETS
  disagreement is allowed to look like).
- Every expiry is a real, audited change, indistinguishable in the
  audit log from a person manually turning the flag off — "who changed
  this" is always answerable, even when the answer is "nobody did,
  this was always going to happen."
- `expire_due_flag_states/0` only touches rows that are still
  `enabled`; an already-off flag with a stale `expires_at` is left
  alone rather than generating a redundant "turned off" audit entry
  every 5 minutes.
