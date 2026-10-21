# Populates a demo user with two environments and three flags at
# realistic states in each, so a fresh clone or a public demo
# deployment has something to look at immediately.
#
#     mix run priv/repo/seeds.exs
#
# Every flag state goes through Flags.set_flag_state/4, the same
# function the dashboard uses, so the audit log is a real, genuine
# history of these calls, not synthetic data shaped to look like one.
#
# Safe to run more than once: it does nothing if the demo user already
# has an environment.

alias Beacon.Accounts
alias Beacon.Accounts.User
alias Beacon.Flags
alias Beacon.Repo

demo_email = "demo@beacon.dev"
demo_password = "demo-password-please-change"

user =
  case Repo.get_by(User, email: demo_email) do
    nil ->
      {:ok, user} = Accounts.register_user(%{email: demo_email, password: demo_password})
      user

    existing ->
      existing
  end

if Flags.list_environments(user) == [] do
  {:ok, staging} = Flags.create_environment(user, %{name: "staging"})
  {:ok, production} = Flags.create_environment(user, %{name: "production"})

  {:ok, dashboard} =
    Flags.create_flag(user, %{key: "new-dashboard", description: "The redesigned home dashboard"})

  {:ok, checkout} =
    Flags.create_flag(user, %{key: "checkout-v2", description: "Rebuilt checkout flow"})

  {:ok, dark_mode} = Flags.create_flag(user, %{key: "dark-mode", description: "Dark color theme"})

  # (flag, environment, enabled, rollout_percentage)
  states = [
    {dashboard, staging, true, 100},
    {dashboard, production, true, 25},
    {checkout, staging, true, 100},
    {checkout, production, false, 0},
    {dark_mode, staging, true, 100},
    {dark_mode, production, true, 100}
  ]

  for {flag, environment, enabled, rollout_percentage} <- states do
    {:ok, _state} =
      Flags.set_flag_state(user, flag, environment, %{
        enabled: enabled,
        rollout_percentage: rollout_percentage
      })
  end
end

IO.puts("""

Seeded demo user:
  email:    #{demo_email}
  password: #{demo_password}
""")
