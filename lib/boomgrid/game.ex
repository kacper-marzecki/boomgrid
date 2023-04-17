defmodule Boom.Game do
  alias Boom.Game.Round

  defmodule Round do
    defstruct player_moves: %{},
              # the rest is filled in at the end of the round
              # id -> [anchored_spell]
              spells: %{},
              # board state
              effects: []
  end

  defstruct game_id: nil,
            # cached fields
            rounds: [%{__struct__: Boom.Game.Round}],
            spells: [
              %{
                moves: [[0, 2], [0, 4]],
                effects: [
                  %{type: :wall, points: {[-1, 6], [1, 6]}}
                ]
              }
            ]

  def new_game(game_id) do
    %__MODULE__{
      game_id: game_id,
      # cached fields
      rounds: [%Boom.Game.Round{}],
      spells: [
        %{
          moves: [[0, 2], [1, 2]],
          effects: [
            %{type: :wall, points: {[-1, 6], [1, 6]}}
          ]
        },
        %{
          moves: [[0, 2]],
          effects: [
            %{type: :wall, points: {[-1, 3], [1, 3]}}
          ]
        }
      ]
    }
  end

  def rotate([x, y], [cos_o, sin_o] = _rotation_matrix) do
    [x * cos_o - y * sin_o, x * sin_o + y * cos_o]
  end

  def dot([x1, y1], [x2, y2]) do
    x1 * x2 + y1 * y2
  end

  def distance([a, b], [c, d]) do
    :math.sqrt(:math.pow(a - c, 2) + :math.pow(b - d, 2))
  end

  def is_between(a, b, c) do
    d = distance(a, c) + distance(c, b)
    segment = distance(a, b)
    abs(segment - d) < 0.01
  end

  def test do
    %{
      moves: [[0, 2], [0, 4]],
      effects: [
        %{type: :wall, points: {[-1, 6], [1, 6]}}
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
          Enum.map(effects, fn eff ->
            case eff do
              %{type: :wall, points: {a, b}} ->
                %{eff | points: {rotate(a, rotation_matrix), rotate(b, rotation_matrix)}}
            end
          end)

        %{spell | moves: moves, effects: effects}
      end)

    [spell | rotated]
  end

  def add_position_vecs([a_x, a_y], [b_x, b_y]), do: [a_x + b_x, a_y + b_y]

  def anchor(%{moves: moves, effects: effects} = spell, position) do
    moves = Enum.map(moves, fn move -> add_position_vecs(move, position) end)

    effects =
      Enum.map(effects, fn eff ->
        case eff do
          %{type: :wall, points: {a, b}} ->
            %{eff | points: {add_position_vecs(a, position), add_position_vecs(b, position)}}
        end
      end)

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
        {:ok, %{game | rounds: List.replace_at(game.rounds, 0, new_round)}}

      %{cmd: :next_round} ->
        %Round{} = round = hd(game.rounds)
        # TODO
        # render new board
        # this doesnt have to he exactly whats displayed, x, y stay the same, regardless of the rendered map;
        spells =
          Map.new(round.player_moves, fn {player_id, move} ->
            # generate spells for the new position the players are in
            new_spells =
              game.spells
              |> Enum.flat_map(fn spell -> rotations(spell) end)
              |> Enum.map(fn spell -> anchor(spell, move) end)

            # find which spells are triggered by the new moves
            spells_after_moving =
              Map.get(round.spells, player_id, [])
              |> Enum.flat_map(fn spell ->
                case spell.moves do
                  [^move | next_moves] -> [%{spell | moves: next_moves}]
                  _other -> []
                end
              end)

            {player_id, Enum.concat(spells_after_moving, new_spells)}
          end)

        # find which spells are triggered by the new moves
        effects =
          Enum.flat_map(spells, fn {player_id, player_spells} ->
            Enum.flat_map(player_spells, fn spell ->
              case spell do
                # ready to cast, no more moves remaining
                %{moves: [], effects: effects} ->
                  Enum.map(effects, fn eff -> Map.put(eff, :player_id, player_id) end)

                _ ->
                  []
              end
            end)
          end)

        next_round = %Round{
          spells: spells,
          effects: round.effects ++ effects
        }

        {:ok, %{game | rounds: [next_round | game.rounds]}}

      %{cmd: :attack, target: _target} ->
        nil

      %{cmd: :super_attack, target: _target} ->
        nil
    end
  end

  # TODO NEXT - game_live.ex render if a point is a wall
  def wall?(%__MODULE__{rounds: [round | _]}, x, y) do
    Enum.any?(round.effects, fn
      %{type: :wall, points: {a, b}, player_id: _player_id} ->
        is_between(a, b, [x, y])
    end)
  end

  def player_position?(%__MODULE__{rounds: [round | _]}, player, x, y) do
    case Map.get(round.player_moves, player) do
      [^x, ^y] -> true
      _ -> false
    end
  end

  # def block do
  #   %{
  #     player: 1,
  #     start: [2, 5]
  #   }
  # end

  def can_move?(%__MODULE__{rounds: [_round | _]} = _game, _player, _destination) do
    # TODO could a player be able to pass through his own walls ?
  end
end
