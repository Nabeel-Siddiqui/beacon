defmodule Beacon.Flags.Cache do
  @moduledoc """
  An ETS read cache of every flag's state, so evaluating a flag is a
  local lookup, not a database hit. Postgres is always the source of
  truth (see CLAUDE.md); this table only ever mirrors it.

  The table is `:public` so any process can read it directly without
  going through this GenServer, but every write is still funneled
  through `put/4`'s `GenServer.call` — a single writer serializes
  updates, even though ETS itself would technically allow concurrent
  writers.

  Loading every flag's state from Postgres at boot would run before any
  test owns a sandboxed connection, crashing the whole supervision tree
  under `mix test`. `:warm_cache_on_boot` is `true` in dev/prod and
  `false` in test (config/test.exs); tests that want to exercise the
  boot-time load call `warm!/0` directly, after explicitly allowing this
  process their sandbox connection.
  """

  use GenServer

  alias Beacon.Flags

  @table __MODULE__

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Looks up a flag's cached state for one user and environment. `:error` on a cache miss."
  @spec lookup(pos_integer(), String.t(), String.t()) :: {:ok, map()} | :error
  def lookup(user_id, environment_name, flag_key) do
    case :ets.lookup(@table, {user_id, environment_name, flag_key}) do
      [{_key, value}] -> {:ok, value}
      [] -> :error
    end
  end

  @doc "Writes one entry into the cache. Used whenever a flag's state changes."
  @spec put(pos_integer(), String.t(), String.t(), map()) :: :ok
  def put(user_id, environment_name, flag_key, value) do
    GenServer.call(__MODULE__, {:put, {user_id, environment_name, flag_key}, value})
  end

  @doc "Loads every flag's state from Postgres into the cache, replacing what's there. Synchronous."
  @spec warm!() :: :ok
  def warm! do
    GenServer.call(__MODULE__, :warm)
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

    if Application.get_env(:beacon, :warm_cache_on_boot, true) do
      {:ok, %{}, {:continue, :warm}}
    else
      {:ok, %{}}
    end
  end

  @impl true
  def handle_continue(:warm, state) do
    load_all()
    {:noreply, state}
  end

  @impl true
  def handle_call({:put, key, value}, _from, state) do
    :ets.insert(@table, {key, value})
    {:reply, :ok, state}
  end

  def handle_call(:warm, _from, state) do
    load_all()
    {:reply, :ok, state}
  end

  defp load_all do
    for {user_id, environment_name, flag_key, enabled, rollout_percentage} <-
          Flags.list_all_states_for_cache() do
      :ets.insert(
        @table,
        {{user_id, environment_name, flag_key},
         %{enabled: enabled, rollout_percentage: rollout_percentage}}
      )
    end
  end
end
