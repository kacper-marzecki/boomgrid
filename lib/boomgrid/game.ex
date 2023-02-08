defmodule Boom.Game do
  alias Boom.Game.Round

  defstruct players: [],
            game_id: nil,
            # cached fields
            blocks: [],
            rounds: [%Round{}],
            spells: [
              %{
                moves: [[0, 2], [0, 4]],
                effects: [
                  %{type: :block, position: [-1, 6]},
                  %{type: :block, position: [0, 6]},
                  %{type: :block, position: [1, 6]}
                ]
              }
            ]

  defmodule Round do
    defstruct player_moves: %{},
              # the rest is filled in at the end of the round
              # id -> [anchored_spell]
              spells: %{},
              # board state
              effects: []
  end

  # def join(%__MODULE__{players: players} = game, opaque_player_data) do
  #   can_join? = Enum.member?(players, opaque_player_data) || length(players) < 2

  #   if can_join? do
  #     {:ok, %{game | players: [opaque_player_data | players]}
  #   else
  #     {:error, game}
  #   end
  # end

  def rotate([x, y], [cos_o, sin_o] = _rotation_matrix) do
    [x * cos_o - y * sin_o, x * sin_o + y * cos_o]
  end

  def test do
    %{
      moves: [[0, 2], [0, 4]],
      effects: [
        %{type: :block, position: [-1, 6]},
        %{type: :block, position: [0, 6]},
        %{type: :block, position: [1, 6]}
      ]
    }
    |> rotations()
    |> Enum.map(fn x -> anchor(x, [7, 4]) end)
  end

  def rotations(%{moves: moves, effects: effects} = spell) do
    rotated =
      [
        [0, 1],
        [-1, 0],
        [0, -1]
      ]
      |> Enum.map(fn rotation_matrix ->
        moves = Enum.map(moves, fn move -> rotate(move, rotation_matrix) end)

        effects =
          Enum.map(effects, fn eff -> %{eff | position: rotate(eff.position, rotation_matrix)} end)

        %{spell | moves: moves, effects: effects}
      end)

    [spell | rotated]
  end

  def add_position_vecs([a_x, a_y], [b_x, b_y]), do: [a_x + b_x, a_y + b_y]

  def anchor(%{moves: moves, effects: effects} = spell, position) do
    moves = Enum.map(moves, fn move -> add_position_vecs(move, position) end)

    effects =
      Enum.map(effects, fn eff -> %{eff | position: add_position_vecs(eff.position, position)} end)

    %{spell | moves: moves, effects: effects}
    |> Map.put(:anchor, position)
  end

  def command(%__MODULE__{} = game, %{} = cmd) do
    case cmd do
      %{cmd: :move, to: destination, player_id: player_id} ->
        round = hd(game.rounds)
        # TODO
        # check if player can move like that,
        # check for collisions
        new_round = %{round | player_moves: Map.put(round.player_moves, player_id, destination)}
        {:ok, %{game | List.replace_at(0, new_round)}}

      %{cmd: :next_round} ->
        %Round{} = round = hd(game.rounds)
        # TODO
        # spells
        # find which spells are triggered by the new moves
        # generate spells for the new position the players are in
        # render new board
        # this doesnt have to he exactly whats displayed, x, y stay the same, regardless of the rendered map;
        Enum.map(round.player_moves, fn {player_id, move} ->
          nil
        end)

        next_round = %Round{}
        {:ok, %{game | rounds: [next_round | game.rounds]}}

      %{cmd: :attack, target: target} ->
        nil

      %{cmd: :super_attack, target: target} ->
        nil
    end
  end

  def block do
    %{
      player: 1,
      start: [2, 5]
    }
  end

  def can_move?(%__MODULE__{players: players} = game, player, destination) do
    game.blocks
  end
end
