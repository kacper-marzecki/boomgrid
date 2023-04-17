defmodule Boom.Ankh do
  use Pathex
  alias Pathex.Lenses

  def new_game do
    %{
      money: %{},
      decks: %{
        graveyard: [],
        events: [],
        actions: [%{id: 3}],
        characters: [],
        table: [],
        kacper: [],
        szczepan: []
      },
      tokens: [],
      colors: %{}
    }
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
    from_deck = path(:decks / from) |> Pathex.get(game)

    game
    |> Pathex.over!(path(:decks / to), fn deck -> from_deck ++ deck end)
    |> Pathex.set!(path(:decks / from), [])
  end

  def move_n_cards_from_deck_to_deck(game, n, from, to) do
    from_deck = path(:decks / from) |> Pathex.get(game)

    cards = Enum.take(from_deck, n)
    from_deck = Enum.drop(cards, n)

    game
    |> Pathex.over!(path(:decks / to), fn deck -> cards ++ deck end)
    |> Pathex.set!(path(:decks / from), from_deck)
  end

  def all_decks_path() do
    path(:decks) ~> Lenses.star()
  end

  def move_card_to_deck(game, card_id, deck_id) do
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
    |> Pathex.over!(path(:decks / deck_id), fn deck -> [card | deck] end)
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
    |> Pathex.over!(path(:money), fn money_map -> Map.put(money_map, player, 10) end)
    |> move_n_cards_from_deck_to_deck(5, :actions, player)
    |> move_n_cards_from_deck_to_deck(1, :characters, player)
    |> Pathex.set!(path(:colors / player), unused_color)
  end

  def colors() do
    [:blue, :red, :green, :yellow]
  end

  def gen_id(), do: System.unique_integer([:positive, :monotonic])
end
