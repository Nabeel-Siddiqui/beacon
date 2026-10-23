# 4. API tokens don't expire; they're revoked

## Status

Accepted (SDK endpoint).

## Context

`users_tokens` already exists for session, email-confirmation, and
password-reset tokens, each with a context string and a validity
window checked at verification time (`UserToken.days_for_context/1`).
The SDK endpoint needed its own token type for machine-to-machine
calls — something a deployed service holds onto and sends on every
request, not something a human re-authenticates with periodically.

## Decision

API tokens reuse the same `users_tokens` table and the same
hash-at-rest scheme (`build_hashed_token/3`) as the existing email
tokens, under a new `"api"` context — but `verify_api_token_query/1`
checks no expiry window at all. A token is valid from the moment it's
generated until a `delete_user_api_token/2` call removes its row.
There's no background job to expire old ones, because there's nothing
to expire.

## Alternatives considered

- **Give API tokens the same kind of expiry window as session
  tokens** (e.g. 90 days). Mirrors the existing pattern exactly, but a
  token embedded in a deployed service's config silently going dead
  on a timer is a worse failure mode for a feature-flag check than a
  token that lives until someone deliberately revokes it — the whole
  point of a flag service is to stay fast and available on a path
  other services depend on.
- **A separate `ApiToken` schema**, rather than reusing
  `users_tokens`. Would make the "no expiry" rule explicit in the
  schema instead of in a function clause, but introduces a second
  table and a second hashing code path for something that's
  structurally identical to what already exists — the kind of
  complexity this app's own conventions ask not to add without a real
  need for it.

## Consequences

- Revoking is the only way a token stops working — `Accounts.delete_user_api_token/2`,
  wired to the "Revoke" button in Settings. There's no
  "it just expired" support question to field, but also no automatic
  cleanup of a token someone forgot to revoke.
- Settings only ever shows a token's id and creation date, never the
  raw value again — losing a token means revoking it and generating a
  new one, the same trade-off the email/reset tokens already make by
  being one-time use.
- A compromised token is a real, standing risk until someone notices
  and revokes it (see "what I'd do next" in the README for scoping
  and rate-limiting as the next layer of defense).
