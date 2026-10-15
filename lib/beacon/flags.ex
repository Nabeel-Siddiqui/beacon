defmodule Beacon.Flags do
  @moduledoc """
  Environments, flags, each flag's state per environment, and the audit
  log of every state change.

  Every function that reads or writes an environment or flag a user
  doesn't own returns `{:error, :not_found}`, not `{:error, :unauthorized}`
  — a guessed id reveals nothing about whether it exists.
  """

  import Ecto.Query, warn: false

  alias Beacon.Accounts.User
  alias Beacon.Flags.{AuditLogEntry, Environment, Flag, FlagState}
  alias Beacon.Repo

  @doc "Creates an environment owned by `user`."
  @spec create_environment(User.t(), map()) ::
          {:ok, Environment.t()} | {:error, Ecto.Changeset.t()}
  def create_environment(%User{} = user, attrs) do
    %Environment{user_id: user.id}
    |> Environment.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Fetches an environment by id, scoped to `user`."
  @spec get_environment(User.t(), term()) :: {:ok, Environment.t()} | {:error, :not_found}
  def get_environment(%User{} = user, id) do
    with {:ok, int_id} <- cast_id(id),
         %Environment{} = environment <- Repo.get_by(Environment, id: int_id, user_id: user.id) do
      {:ok, environment}
    else
      _ -> {:error, :not_found}
    end
  end

  @doc "Lists `user`'s environments, alphabetically."
  @spec list_environments(User.t()) :: [Environment.t()]
  def list_environments(%User{} = user) do
    Environment
    |> where([e], e.user_id == ^user.id)
    |> order_by([e], asc: e.name)
    |> Repo.all()
  end

  @doc "Creates a flag owned by `user`."
  @spec create_flag(User.t(), map()) :: {:ok, Flag.t()} | {:error, Ecto.Changeset.t()}
  def create_flag(%User{} = user, attrs) do
    %Flag{user_id: user.id}
    |> Flag.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Fetches a flag by id, scoped to `user`."
  @spec get_flag(User.t(), term()) :: {:ok, Flag.t()} | {:error, :not_found}
  def get_flag(%User{} = user, id) do
    with {:ok, int_id} <- cast_id(id),
         %Flag{} = flag <- Repo.get_by(Flag, id: int_id, user_id: user.id) do
      {:ok, flag}
    else
      _ -> {:error, :not_found}
    end
  end

  @doc "Lists `user`'s flags, alphabetically by key."
  @spec list_flags(User.t()) :: [Flag.t()]
  def list_flags(%User{} = user) do
    Flag
    |> where([f], f.user_id == ^user.id)
    |> order_by([f], asc: f.key)
    |> Repo.all()
  end

  @doc """
  `flag`'s state in `environment`. A flag with no state recorded yet for
  that environment reads as off at 0%, the same as if someone had set it
  that way explicitly — this never returns `{:error, :not_found}`.
  """
  @spec get_flag_state(Flag.t(), Environment.t()) :: FlagState.t()
  def get_flag_state(%Flag{} = flag, %Environment{} = environment) do
    FlagState
    |> Repo.get_by(flag_id: flag.id, environment_id: environment.id)
    |> case do
      %FlagState{} = state -> state
      nil -> %FlagState{flag_id: flag.id, environment_id: environment.id}
    end
  end

  @doc """
  Sets `flag`'s state in `environment` and records who changed it to what,
  in one transaction. `user` must own both the flag and the environment.
  """
  @spec set_flag_state(User.t(), Flag.t(), Environment.t(), map()) ::
          {:ok, FlagState.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def set_flag_state(%User{} = user, %Flag{} = flag, %Environment{} = environment, attrs) do
    with {:ok, flag} <- get_flag(user, flag.id),
         {:ok, environment} <- get_environment(user, environment.id) do
      state = get_flag_state(flag, environment)
      changeset = FlagState.changeset(state, attrs)

      Ecto.Multi.new()
      |> Ecto.Multi.insert_or_update(:flag_state, changeset)
      |> Ecto.Multi.insert(:audit_log_entry, fn %{flag_state: flag_state} ->
        AuditLogEntry.changeset(
          %AuditLogEntry{
            flag_id: flag.id,
            environment_id: environment.id,
            user_id: user.id
          },
          %{enabled: flag_state.enabled, rollout_percentage: flag_state.rollout_percentage}
        )
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{flag_state: flag_state}} -> {:ok, flag_state}
        {:error, :flag_state, changeset, _changes} -> {:error, changeset}
      end
    end
  end

  @doc "Lists `flag`'s audit log, newest first."
  @spec list_audit_log(Flag.t()) :: [AuditLogEntry.t()]
  def list_audit_log(%Flag{} = flag) do
    AuditLogEntry
    |> where([a], a.flag_id == ^flag.id)
    |> order_by([a], desc: a.inserted_at, desc: a.id)
    |> preload([:environment, :user])
    |> Repo.all()
  end

  defp cast_id(id) do
    case Integer.parse(to_string(id)) do
      {int_id, ""} -> {:ok, int_id}
      _ -> :error
    end
  end
end
