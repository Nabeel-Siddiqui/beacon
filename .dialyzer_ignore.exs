[
  # Known false positive: Dialyzer can't see through Ecto.Multi's opaque
  # struct across `Ecto.Multi.new() |> Ecto.Multi.update(:user, changeset)`
  # pipelines. Reproduces on stock `mix phx.gen.auth` output (the sites in
  # accounts.ex that update a user inside a multi alongside deleting their
  # old tokens), not something this app's own code caused.
  {"lib/beacon/accounts.ex", :call_without_opaque},

  # Same opaque-Ecto.Multi false positive as above, this time on
  # `Ecto.Multi.insert_or_update/3` in Flags.set_flag_state/4.
  {"lib/beacon/flags.ex", :call_without_opaque}
]
