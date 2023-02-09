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
    |> IO.inspect()
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

  def start_new_game() do
    game_id = :rand.uniform(100_000)

    name = {:via, Registry, {Boom.GameRegistry, game_process_name(game_id)}}

    {:ok, _pid} =
      DynamicSupervisor.start_child(
        Boom.GameSupervisor,
        {__MODULE__, name: name, game_id: game_id}
      )

    {:ok, game_id}
  end

  def process_name_tuple(game_id) do
    {:via, Registry, {Boom.GameRegistry, game_process_name(game_id)}}
  end

  def game_process_name(game_id) do
    "game/#{game_id}"
  end

  # API for processes to join the game with a username
  def join_and_subscribe_me!(game_id, username) do
    with :ok <-
           GenServer.call(
             process_name_tuple(game_id),
             {:join, username}
           ) do
      :ok = Phoenix.PubSub.subscribe(Boom.PubSub, "game/#{game_id}")
    end
  end

  def get_game(game_id) do
    try do
      {:ok, :sys.get_state(process_name_tuple(game_id))}
    catch
      :exit, _ ->
        {:error, :not_found}
    end
  end

  def command(game_id, username, command) do
    process_name_tuple(game_id)
    |> GenServer.call({:command, username, command})
  end

  ########################################################################
  # GenServer handlers
  ########################################################################
  # TODO: handle  n-player restrictions, spectators, modifications to the game  after joining, but before starting

  def handle_call({:join, username}, {pid, _}, %{players: players} = state) do
    player_id = Enum.max_by(players, fn player -> player.id end, fn -> 0 end) + 1
    players = [%{id: player_id, username: username, pid: pid} | players]
    Process.monitor(pid)
    {:reply, :ok, %{state | players: players}}
  end

  def handle_call({:command, username, cmd}, _, %{game: game, players: players} = state) do
    case Enum.find(players, fn %{username: ^username} -> username end) do
      nil ->
        {:reply, {:error, :not_a_player}, state}

      %{id: id} ->
        command = Map.put(cmd, :player_id, id)

        case Boom.Game.command(game, command) do
          {:ok, new_game} ->
            broadcast_game(new_game)
            {:reply, :ok, %{state | game: new_game}}

          {:error, reason} ->
            Logger.error("""
            Game Command error
            reason: #{reason}
            cmd: #{inspect(cmd)}
            server state: #{inspect(state)}
            """)

            {:reply, :error, state}
        end
    end
  end

  # when the client process exits, remove the player from the game
  def handle_info(
        {:DOWN, _ref, :process, object, _reason},
        %{players: players} = state
      ) do
    only_live_players = Enum.filter(players, fn %{pid: pid} -> pid != object end)
    {:noreply, %{state | players: only_live_players}}
  end

  ########################################################################
  # PubSub functions
  ########################################################################

  def broadcast_game(game) do
    Phoenix.PubSub.broadcast(Boom.PubSub, "game/#{game.game_id}", {:new_game_state, game})
  end

  ########################################################################
  # Lifecycle handlers
  ########################################################################

  def init(opts) do
    Process.flag(:trap_exit, true)
    {:ok, %{game: Boom.Game.new_game(Keyword.fetch!(opts, :game_id)), players: []}, @timeout}
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
