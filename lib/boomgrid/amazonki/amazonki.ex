defmodule Boom.Amazonki do
  require Logger

  @card_count_per_players %{
    3 => %{empty: 8, gold: 5, trap: 2},
    4 => %{empty: 12, gold: 6, trap: 2},
    5 => %{empty: 16, gold: 7, trap: 2},
    6 => %{empty: 20, gold: 8, trap: 2}
  }

  @roles_per_players %{
    3 => %{robber: 2, amazon: 2},
    4 => %{robber: 3, amazon: 2},
    5 => %{robber: 3, amazon: 2},
    6 => %{robber: 4, amazon: 2}
  }

  def new_game do
    %{
      doors: [],
      players: [],
      player_roles: %{},
      cards: [],
      card_count: nil,
      player_cards: %{},
      chosen_cards: [],
      key_holder: nil,
      round: 0,
      winner: nil,
      log: []
    }
  end

  def new_cards(range, type) do
    for _ <- range do
      %{
        id: "#{type}_#{Boom.Id.gen_id()}",
        type: type,
        image: "/images/amazonki/#{type}.png",
        reverse_image: "/images/amazonki/#{type}_reverse.png"
      }
    end
    |> Enum.shuffle()
  end

  def add_player(%{round: 0} = game, player) do
    %{game | players: [player | game.players]}
    |> add_log("#{player} joined")
  end

  def can_start_game?(game) do
    Map.get(@roles_per_players, length(game.players)) != nil
  end

  def start_game(%{round: 0} = game) do
    player_count = length(game.players)

    %{robber: robber_count, amazon: amazon_count} =
      roles_count = Map.get(@roles_per_players, player_count)

    roles =
      roles_count
      |> Enum.flat_map(fn {type, count} -> List.duplicate(type, count) end)
      |> Enum.shuffle()

    {_unused_roles, player_roles} =
      Enum.reduce(game.players, {roles, %{}}, fn player, {[role | roles], player_roles} ->
        {roles, Map.put(player_roles, player, role)}
      end)

    %{empty: _, gold: _, trap: _} = card_count = Map.get(@card_count_per_players, player_count)

    cards =
      card_count
      |> Enum.flat_map(fn {type, count} -> List.duplicate(type, count) end)
      |> Enum.shuffle()

    player_cards =
      Enum.zip([game.players, Enum.chunk_every(cards, 5)])
      |> Enum.into(%{})

    %{
      game
      | round: 1,
        card_count: card_count,
        player_roles: player_roles,
        player_cards: player_cards,
        # cards: cards,
        chosen_cards: [],
        key_holder: Enum.random(game.players)
    }
    |> add_log("game started")
  end

  def choose_door(%{key_holder: key_holder} = game, player) when key_holder != player do
    [card | cards] = game.player_cards[player]

    game
    |> Map.update!(:player_cards, fn player_cards ->
      Map.put(player_cards, player, cards)
    end)
    |> Map.put(:chosen_cards, [card | game.chosen_cards])
    |> Map.put(:key_holder, player)
    |> add_log("#{key_holder} trusted #{player}: #{card}")
    |> case do
      game ->
        if length(game.chosen_cards) > 0 and
             Integer.mod(length(game.chosen_cards), length(game.players)) == 0 do
          game = Map.update!(game, :round, fn a -> a + 1 end)
          cards = Map.values(game.player_cards) |> List.flatten()

          new_player_cards =
            Enum.zip([game.players, Enum.chunk_every(cards, 5 - game.round + 1)])
            |> Enum.into(%{})

          %{game | player_cards: new_player_cards}
          |> add_log("new round: #{game.round}")
        else
          game
        end
    end
    |> case do
      game ->
        winner =
          cond do
            game.chosen_cards |> Enum.count(fn card -> card == :trap end) == 2 ->
              :amazon

            game.chosen_cards |> Enum.count(fn card -> card == :gold end) == game.card_count.gold ->
              :robber

            game.round == 5 ->
              :amazon

            true ->
              nil
          end

        %{game | winner: winner}
    end
  end

  def count_open_doors(game, type) do
    game.chosen_cards |> Enum.count(fn card -> card == type end)
  end

  def count_player_doors(game, player, type) do
    game.player_cards |> Map.get(player) |> Enum.count(fn card -> card == type end)
  end

  def add_log(game, log) do
    # now = DateTime.now!("Etc/UTC") |> DateTime.to_time() |> Time.truncate(:second)

    Map.update!(game, :log, fn logs ->
      ["#{log}" | Enum.reverse(logs)] |> Enum.reverse()
    end)
  end
end
