defmodule Boom.Ankh do
  use Pathex
  alias Pathex.Lenses
  require Logger

  def new_game do
    %{
      money: %{},
      decks: %{
        graveyard: [],
        events: new_cards(0..11, :event),
        actions: new_cards(0..100, :action),
        characters: new_cards(0..6, :character),
        districts: new_cards(0..11, :district),
        table: []
      },
      tokens: starting_tokens(),
      colors: %{},
      log: ["game started"]
    }
  end

  def new_cards(range, type) do
    for id <- range do
      %{
        id: "#{type}_#{gen_id()}",
        type: type,
        image: "/images/ankh/#{type}_#{id}.png",
        reverse_image: "/images/ankh/#{type}_reverse.png"
      }
    end
    |> Enum.shuffle()
  end

  def starting_tokens() do
    [
      %{
        sprite: %{url: "/images/ankh_morpork_plansza.jpg", size: 500},
        position: %{x: 0, y: 0, z: 0},
        id: gen_id(),
        background: true
      }
    ]
  end

  def place_token(game, %{} = token, player) do
    Pathex.over!(game, path(:tokens), fn tokens ->
      [token | Enum.reverse(tokens)] |> Enum.reverse()
    end)
    |> add_log("#{player} położył #{token.type}")
  end

  def remove_token(game, id, player) do
    token_filter = fn token -> token.id != id end
    token = game.tokens |> Enum.find(fn tok -> tok.id == id end)

    Pathex.over!(game, path(:tokens), fn tokens -> Enum.filter(tokens, token_filter) end)
    |> add_log("#{player} usunął #{token.type}")
  end

  def move_token(game, id, x, y, player) do
    p = path(:tokens) ~> Lenses.star() ~> Lenses.matching(%{id: ^id}) ~> path(:position)
    token = game.tokens |> Enum.find(fn tok -> tok.id == id end)

    Pathex.over!(game, p, fn token_position ->
      Map.merge(token_position, %{x: x, y: y})
    end)
    |> add_log("#{player} przesunął #{token.type}")
  end

  def shuffle_deck(game, deck_id, player) do
    p = path(:decks / deck_id)

    Pathex.over!(game, p, fn deck -> Enum.shuffle(deck) end)
    |> add_log("#{player} potasował talię: #{deck_id}")
  end

  def move_all_cards_from_deck_to_deck(game, from, to, player) do
    from_deck = Pathex.get(game, path(:decks / from))

    game
    |> Pathex.over!(path(:decks / to), fn deck -> from_deck ++ deck end)
    |> Pathex.set!(path(:decks / from), [])
    |> add_log("#{player} przeniósł wszystkie karty z talii #{from} do talii #{to}")
  end

  def move_n_cards_from_deck_to_deck(game, n, from, to, player) do
    Logger.debug("Moving #{n} cards, from #{from} to  #{to}")
    from_deck = Pathex.get(game, path(:decks / from))
    cards = Enum.take(from_deck, n)
    from_deck = Enum.drop(from_deck, n)

    game
    |> Pathex.over!(path(:decks / to), fn deck -> cards ++ deck end)
    |> Pathex.set!(path(:decks / from), from_deck)
    |> add_log("#{player} przeniósł #{n} kart z talii #{from} do talii #{to}")
  end

  def all_decks_path() do
    path(:decks) ~> Lenses.star()
  end

  def move_card_to_deck(game, card_id, deck_id, position \\ "first", player) do
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
    |> add_log("#{player} przeniósł kartę #{card_id} do talii #{deck_id} na pozycji #{position}")
  end

  def money_change(game, player, diff, actor_player) do
    Pathex.over!(game, path(:money / player), fn money -> money + diff end)
    |> add_log("#{actor_player} zmienił forsę gracza #{player} #{diff}$")
  end

  def add_player(game, player) do
    used_colors = Pathex.get(game, path(:colors) ~> Lenses.all())

    unused_color =
      Enum.find(colors(), fn color -> !Enum.member?(used_colors, color) end) ||
        raise("wiecej nei da rady")

    game
    |> Pathex.over!(path(:money), &Map.put(&1, player, 10))
    |> Pathex.over!(path(:decks), &Map.put(&1, player, []))
    |> move_n_cards_from_deck_to_deck(5, :actions, player, player)
    |> move_n_cards_from_deck_to_deck(1, :characters, player, player)
    |> Pathex.over!(path(:colors), &Map.put(&1, player, unused_color))
  end

  def colors() do
    [:blue, :red, :green, :yellow, :dotted]
  end

  def token_types() do
    [
      %{type: :blue_agent, sprite: %{url: "/images/ankh/blue_agent.png", size: 20}},
      %{type: :blue_building, sprite: %{url: "/images/ankh/blue_building.png", size: 20}},
      %{type: :demon, sprite: %{url: "/images/ankh/demon.png", size: 20}},
      %{type: :disturbance, sprite: %{url: "/images/ankh/disturbance.png", size: 20}},
      %{type: :green_agent, sprite: %{url: "/images/ankh/green_agent.png", size: 20}},
      %{type: :green_building, sprite: %{url: "/images/ankh/green_building.png", size: 20}},
      %{type: :red_agent, sprite: %{url: "/images/ankh/red_agent.png", size: 20}},
      %{type: :red_building, sprite: %{url: "/images/ankh/red_building.png", size: 20}},
      %{type: :troll, sprite: %{url: "/images/ankh/troll.png", size: 20}},
      %{type: :yellow_agent, sprite: %{url: "/images/ankh/yellow_agent.png", size: 20}},
      %{type: :yellow_building, sprite: %{url: "/images/ankh/yellow_building.png", size: 20}},
      %{type: :dotted_agent, sprite: %{url: "/images/ankh/dotted_agent.png", size: 20}},
      %{type: :dotted_building, sprite: %{url: "/images/ankh/dotted_building.png", size: 20}}
    ]
  end

  def new_token(token_type) do
    token_types()
    |> Enum.find(fn
      %{type: ^token_type} -> true
      _ -> false
    end)
    |> case do
      map -> Map.put(map, :id, gen_id())
    end
  end

  def gen_id(), do: System.unique_integer([:positive, :monotonic])

  def add_log(game, log) do
    Map.update!(game, :log, fn logs -> [log | logs] end)
  end

  ###############################################################

  def find_card(game, card_id) do
    Map.values(game.decks)
    |> List.flatten()
    |> Enum.find(fn card -> card.id == card_id end)
  end

  def find_card_deck(game, card) do
    {deck_id, _} = Enum.find(game.decks, fn {_deck_id, deck} -> card in deck end)
    deck_id
  end
end
