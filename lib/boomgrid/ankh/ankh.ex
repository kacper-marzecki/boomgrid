defmodule Boom.Ankh do
  use Pathex
  alias Pathex.Lenses
  require Logger

  def new_game do
    %{
      money: %{},
      decks: %{
        graveyard: [],
        events: [],
        actions: new_cards(1..9, "action"),
        characters: [],
        districts: [],
        table: []
      },
      tokens: [],
      colors: %{}
    }
  end

  def new_cards(range, type) do
    for id <- range do
      %{
        id: "#{id}",
        image: "/images/ankh/#{type}_#{id}.png",
        reverse_image: "/images/ankh/#{type}_reverse.png"
      }
    end
  end

  def place_token(game, %{x: _x, y: _y, sprite: _sprite} = agent) do
    Pathex.over!(game, path(:tokens), fn tokens -> [Map.put(agent, :id, gen_id()) | tokens] end)
  end

  def remove_token(game, id) do
    token_filter = fn token -> token.id != id end
    Pathex.over!(game, path(:tokens), fn tokens -> Enum.filter(tokens, token_filter) end)
  end

  def move_token(game, id, x, y) do
    p = path(:tokens) ~> Lenses.star() ~> Lenses.matching(%{id: ^id})

    Pathex.over!(game, p, fn token ->
      Map.merge(token, %{x: x, y: y})
    end)
  end

  def shuffle_deck(game, deck_id) do
    p = path(:decks / deck_id)
    Pathex.over!(game, p, fn deck -> Enum.shuffle(deck) end)
  end

  def move_all_cards_from_deck_to_deck(game, from, to) do
    from_deck = Pathex.get(game, path(:decks / from))

    game
    |> Pathex.over!(path(:decks / to), fn deck -> from_deck ++ deck end)
    |> Pathex.set!(path(:decks / from), [])
  end

  def move_n_cards_from_deck_to_deck(game, n, from, to) do
    Logger.debug("Moving #{n} cards, from #{from} to  #{to}")
    from_deck = Pathex.get(game, path(:decks / from))
    cards = Enum.take(from_deck, n)
    from_deck = Enum.drop(from_deck, n)

    game
    |> Pathex.over!(path(:decks / to), fn deck -> cards ++ deck end)
    |> Pathex.set!(path(:decks / from), from_deck)
  end

  def all_decks_path() do
    path(:decks) ~> Lenses.star()
  end

  def move_card_to_deck(game, card_id, deck_id, position \\ "first") do
    # ?? Major PITA
    [[card]] =
      Pathex.get(
        game,
        all_decks_path()
        ~> Lenses.star()
        ~> Lenses.matching(%{id: ^card_id})
      )

    game
    |> Pathex.over!(all_decks_path(), fn deck -> List.delete(deck, card) end)
    |> Pathex.over!(path(:decks / deck_id), fn deck ->
      index =
        case position do
          "random" -> :rand.uniform(length(deck))
          "first" -> 0
          "last" -> length(deck)
        end

      List.insert_at(deck, index, card)
    end)
  end

  def money_change(game, player, diff) do
    Pathex.over!(game, path(:money / player), fn money -> money + diff end)
  end

  def add_player(game, player) do
    used_colors = Pathex.get(game, path(:colors) ~> Lenses.all())

    unused_color =
      Enum.find(colors(), fn color -> !Enum.member?(used_colors, color) end) ||
        raise("wiecej nei da rady")

    game
    |> Pathex.over!(path(:money), &Map.put(&1, player, 10))
    |> Pathex.over!(path(:decks), &Map.put(&1, player, []))
    |> move_n_cards_from_deck_to_deck(5, :actions, player)
    |> move_n_cards_from_deck_to_deck(1, :characters, player)
    |> Pathex.over!(path(:colors), &Map.put(&1, player, unused_color))
  end

  def colors() do
    [:blue, :red, :green, :yellow]
  end

  def gen_id(), do: System.unique_integer([:positive, :monotonic])

  ###############################################################

  def find_card(game, card_id) do
    Map.values(game.decks)
    |> List.flatten()
    |> Enum.find(fn card -> card.id == card_id end)
  end
end
