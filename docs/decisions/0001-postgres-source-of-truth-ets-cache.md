# 1. Postgres is the source of truth, ETS is a read cache

## Status

Accepted (Phases 2-3).

## Context

Evaluating a flag has to be essentially free — it happens on whatever
hot path is asking "is this feature on for this user," potentially many
times per request across many processes. A database round trip for
every evaluation doesn't scale to that. But a flag's actual state has to
live somewhere durable, survive a restart, and be the single place a
change is made.

## Decision

Every write goes to Postgres first, inside `Flags.set_flag_state/4`'s
own transaction (the `FlagState` row and its `AuditLogEntry` together).
Only after that succeeds does the change propagate anywhere else, as a
`Phoenix.PubSub` broadcast on `Cache.topic/0`. Every `Beacon.Flags.Cache`
instance — one per node, in a real cluster — subscribes to that topic
and updates its own ETS table from `handle_info/2`. There is no direct
call from `set_flag_state/4` into the local cache: a same-node update
and a cross-node one go through the exact same broadcast-and-subscribe
path, because there isn't a separate one for same-node.

`Flags.enabled?/4` reads only the cache. If a lookup misses — nothing
set yet, or this node hasn't caught up to a very recent change — it
returns `false`, the same fail-safe default a flag with no database row
at all already has.

## Alternatives considered

- **Query Postgres on every evaluation, with a short-TTL cache in
  front.** Simpler to reason about, but a TTL cache means staleness is
  bounded by a timer, not by how fast a change actually propagates, and
  every cache miss is still a database round trip on a hot path.
- **A direct call from `set_flag_state/4` into the local cache, in
  addition to broadcasting for other nodes.** Would make same-node
  updates slightly more "direct," but creates two code paths for one
  outcome, and the two could drift if one is changed and the other
  isn't. The broadcast is already effectively instant for a local
  subscriber, so there's no latency this would actually save.

## Consequences

- An evaluation is always a local ETS lookup — no database involved,
  no network hop to another node.
- There's a real, if small, window where a just-changed flag hasn't
  reached every node's cache yet. For this app's purpose, a config
  toggle taking low-single-digit milliseconds to fully propagate is an
  acceptable tradeoff against a flag service that queries a database on
  every check.
- If ETS and Postgres ever disagree, Postgres is right, by construction
  — the cache is a mirror of writes that already succeeded, never an
  independent source.
