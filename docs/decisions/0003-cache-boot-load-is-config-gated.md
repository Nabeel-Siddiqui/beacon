# 3. The cache doesn't load from Postgres at boot in test

## Status

Accepted (Phase 2).

## Context

In production, `Beacon.Flags.Cache` should load every flag's current
state from Postgres as soon as it starts, so the cache is warm before
the first request arrives. But the application's supervision tree boots
once, at the start of the whole `mix test` run — before any individual
test has checked out its own sandboxed database connection. A `Cache`
that eagerly queries the database in `init/1` would run that query with
no connection it's allowed to use, failing with
`DBConnection.OwnershipError` and crashing the whole test suite before a
single test runs.

## Decision

`:warm_cache_on_boot` is an application config flag: `true` in
`config/config.exs` (so dev and prod inherit it), `false` in
`config/test.exs`. `Cache.init/1` only schedules the eager load (via
`handle_continue/2`, so it doesn't block the supervisor on a slow query
either way) when that flag is true. In test, the cache simply starts
empty, and stays that way unless a test explicitly calls `warm!/0` —
which any test exercising the boot-time load path does, after first
calling `Ecto.Adapters.SQL.Sandbox.allow/3` to lend that long-lived
singleton process its own sandboxed connection for the duration of that
one test.

## Alternatives considered

- **Load lazily, on first lookup, instead of at boot.** Avoids the
  boot-time problem entirely, but turns every cold cache's first
  evaluation of each flag into a database read on the hot path —
  exactly what the cache exists to avoid (see
  [ADR 1](0001-postgres-source-of-truth-ets-cache.md)).
- **Skip the eager load in test by checking `Mix.env() == :test` in
  `Cache.init/1` directly.** Works, but hardcodes a test-environment
  branch into application code — the same outcome as the config flag,
  with less flexibility (a config value can be overridden per-test or
  per-environment; an `if Mix.env() == :test` cannot).

## Consequences

- The test suite boots cleanly and every test starts from a known,
  empty cache unless it asks for something else.
- Production and dev get the real behavior — a warm cache from the
  moment the application starts — with no test-only code path standing
  in for it.
- Anyone adding a new test that depends on the cache already being
  warmed has to know to call `warm!/0` (and lend the sandbox
  connection) explicitly; it won't happen implicitly the way it does at
  real application boot.
