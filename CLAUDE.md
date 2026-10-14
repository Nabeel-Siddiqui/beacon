# Beacon — conventions

A feature-flag and rollout service: toggle features per environment, roll
out by percentage, and see changes take effect across every node within
milliseconds. Portfolio-quality Elixir/Phoenix app; hold every change to
these rules. Keep it well-designed and finished, and add complexity only
where this app actually needs it, not speculatively.

## Architecture

- **Business logic lives in contexts** (`Beacon.Accounts`, `Beacon.Flags`,
  ...). Contexts are the only modules that touch `Repo`.
- **The web layer (controllers, LiveViews, plugs) never calls `Repo`
  directly** and never builds `Ecto.Query`s itself. It calls context
  functions.
- **Postgres is the source of truth. ETS is a read cache, never the other
  way around.** A flag's state is written to Postgres first; only after
  that succeeds does it propagate to each node's in-memory table. If ETS
  and Postgres ever disagree, Postgres is right.
- **Percentage rollouts are deterministic, not random.** The same user
  must get the same answer on every evaluation, so bucketing is a hash of
  a stable id, never `:rand`.

## Function contracts

- Every public context function has `@doc` and `@spec`.
- Functions that can fail return `{:ok, result}` or `{:error, reason}`,
  never raising for expected failure modes (validation errors, not-found).
  Reserve `!`-suffixed functions for the conventional Phoenix
  "raise if truly not there" cases.
- No silently swallowed errors. A `rescue` or `catch` that discards the
  error without logging or returning it is a bug.

## Testing

- Every feature ships with tests alongside it in the same phase or commit,
  not "add tests later."
- Prefer testing context functions directly over testing through LiveView
  where the logic under test isn't actually about the UI.

## Style

- Run `mix format` before committing.
- `mix credo --strict` and `mix dialyzer` must be clean before a phase is
  considered done.
