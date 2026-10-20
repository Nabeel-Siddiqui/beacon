defmodule Beacon.Flags.Cache do
  @moduledoc """
  An ETS read cache of every flag's state, so evaluating a flag is a
  local lookup, not a database hit. Postgres is always the source of
  truth (see CLAUDE.md); this table only ever mirrors it.

  Propagation is PubSub, not a direct call: `Beacon.Flags.set_flag_state/4`
  only ever broadcasts on `topic/0`, and every cache instance — the one
  on this node, and one on every other node in a real cluster — updates
  its own table from `handle_info/2`. A real multi-node run can't be
  exercised in this test suite, so `cache_test.exs` stands up a second,
  independently-named instance subscribed to the same topic in its
  place: if that instance's table also updates from a broadcast made
  through this module's own public API, propagation is proven to work
  through the same mechanism a second node actually would use, not a
  shortcut that only looks like it.

  The table is `:public` so any process can read it directly without
  going through this GenServer, but every write — from a `put/4` call or
  from a broadcast — still happens on this process, one at a time.

  Loading every flag's state from Postgres at boot would run before any
  test owns a sandboxed connection, crashing the whole supervision tree
  under `mix test`. `:warm_cache_on_boot` is `true` in dev/prod and
  `false` in test (config/test.exs); tests that want to exercise the
  boot-time load call `warm!/0` directly, after explicitly allowing this
  process their sandbox connection.
  """

  use GenServer

  alias Beacon.Flags

  @topic "beacon:flags"

  @doc "The PubSub topic a flag's state change is broadcast on."
  @spec topic() :: String.t()
  def topic, do: @topic

  @doc "Starts a cache instance. `name:` defaults to this module; pass a different one to run a second, independent instance (as cache_test.exs does to stand in for a second node)."
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, name, name: name)
  end

  @doc "Looks up a flag's cached state for one user and environment. `:error` on a cache miss."
  @spec lookup(GenServer.server(), pos_integer(), String.t(), String.t()) :: {:ok, map()} | :error
  def lookup(server \\ __MODULE__, user_id, environment_name, flag_key) do
    case :ets.lookup(server, {user_id, environment_name, flag_key}) do
      [{_key, value}] -> {:ok, value}
      [] -> :error
    end
  end

  @doc "Writes one entry directly into the cache, bypassing Postgres and PubSub. Mainly a testing tool — the real write path is `Flags.set_flag_state/4`'s broadcast."
  @spec put(GenServer.server(), pos_integer(), String.t(), String.t(), map()) :: :ok
  def put(server \\ __MODULE__, user_id, environment_name, flag_key, value) do
    GenServer.call(server, {:put, {user_id, environment_name, flag_key}, value})
  end

  @doc "Loads every flag's state from Postgres into the cache, replacing what's there. Synchronous."
  @spec warm!(GenServer.server()) :: :ok
  def warm!(server \\ __MODULE__) do
    GenServer.call(server, :warm)
  end

  @doc "A no-op round trip. In a test, calling this after a broadcast guarantees the broadcast was already handled — GenServer processes its mailbox in order, so a message sent first is handled first."
  @spec sync(GenServer.server()) :: :ok
  def sync(server \\ __MODULE__) do
    GenServer.call(server, :sync)
  end

  @impl true
  def init(name) do
    :ets.new(name, [:named_table, :public, :set, read_concurrency: true])
    :ok = Phoenix.PubSub.subscribe(Beacon.PubSub, @topic)

    if Application.get_env(:beacon, :warm_cache_on_boot, true) do
      {:ok, name, {:continue, :warm}}
    else
      {:ok, name}
    end
  end

  @impl true
  def handle_continue(:warm, name) do
    load_all(name)
    {:noreply, name}
  end

  @impl true
  def handle_call({:put, key, value}, _from, name) do
    :ets.insert(name, {key, value})
    {:reply, :ok, name}
  end

  def handle_call(:warm, _from, name) do
    load_all(name)
    {:reply, :ok, name}
  end

  def handle_call(:sync, _from, name) do
    {:reply, :ok, name}
  end

  @impl true
  def handle_info({:flag_state_changed, key, value}, name) do
    :ets.insert(name, {key, value})
    {:noreply, name}
  end

  defp load_all(table_name) do
    for {user_id, environment_name, flag_key, enabled, rollout_percentage} <-
          Flags.list_all_states_for_cache() do
      :ets.insert(
        table_name,
        {{user_id, environment_name, flag_key},
         %{enabled: enabled, rollout_percentage: rollout_percentage}}
      )
    end
  end
end
