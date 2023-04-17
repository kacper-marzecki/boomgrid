defmodule Boom.GameServer do
  use GenServer, restart: :transient
  require Logger
  # 20 minutes
  @timeout 20 * 60 * 1000

  ########################################################################
  # Public API
  ########################################################################

  def list_live_games do
    DynamicSupervisor.which_children(Boom.GameSupervisor)
    |> Enum.flat_map(fn {_, pid, _, _} -> Registry.keys(Boom.GameRegistry, pid) end)
  end

  def active_game_ids do
    list_live_games()
    |> Enum.map(fn game_name -> String.replace_leading(game_name, "game/", "") end)
  end

  def stop_game(game_id) do
    [{pid, _}] = Registry.lookup(Boom.GameRegistry, game_process_name(game_id))
    Process.exit(pid, :normal)
  end

  def start_new_game(type, state) do
    game_id = "#{type}/#{Boom.Id.gen_id()}"

    name = process_name_tuple(game_id)

    {:ok, _pid} =
      DynamicSupervisor.start_child(
        Boom.GameSupervisor,
        {__MODULE__, name: name, game_id: game_id, state: state}
      )

    {:ok, game_id}
  end

  def process_name_tuple(game_id) do
    {:via, Registry, {Boom.GameRegistry, game_process_name(game_id)}}
  end

  def game_process_name(game_id) do
    "game/#{game_id}"
  end

  def subscribe_me!(game_id) do
    :ok = Phoenix.PubSub.subscribe(Boom.PubSub, "game/#{game_id}")
  end

  def get_game(game_id) do
    try do
      {:ok, :sys.get_state(process_name_tuple(game_id))}
    catch
      :exit, _ ->
        {:error, :not_found}
    end
  end

  def execute(game_id, function) do
    process_name_tuple(game_id)
    |> GenServer.call({:execute, function})
  end

  ########################################################################
  # GenServer handlers
  ########################################################################
  # TODO: handle  n-player restrictions, spectators, modifications to the game  after joining, but before starting

  def handle_call({:execute, function}, _from_, %{game: game, game_id: game_id} = state) do
    try do
      new_game = function.(game)
      broadcast_game(game)
      {:reply, :ok, Map.put(state, :game, new_game)}
    rescue
      e ->
        Logger.error("""
        Game #{game_id} error
        #{e}
        """)

        {:reply, {:error, e}, state}
    end
  end

  ########################################################################
  # PubSub helpers
  ########################################################################

  def broadcast_game(%{game: game, game_id: game_id} = _state) do
    Phoenix.PubSub.broadcast(Boom.PubSub, "game/#{game_id}", {:new_game_state, game})
  end

  ########################################################################
  # Lifecycle handlers
  ########################################################################

  def init(opts) do
    Process.flag(:trap_exit, true)

    state = %{
      game: Keyword.fetch!(opts, :state),
      game_id: Keyword.fetch!(opts, :game_id)
    }

    broadcast_game(state)
    {:ok, state, @timeout}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def handle_info({:EXIT, _from, reason}, state) do
    IO.inspect("#{state.game.game_id} Stopped with reason #{inspect(reason)}")
    {:stop, reason, state}
  end

  def handle_info(:timeout, state) do
    IO.inspect("Game #{state.game_id} Timed out")
    {:stop, :normal, state}
  end
end
