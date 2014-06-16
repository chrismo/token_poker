ReverseHoldEm = require('../js/token-poker/reverse-hold-em')
Fakes = require('./fake-time')
Rounds = require('../js/token-poker/round')
Player = require('../js/token-poker/player')

describe 'ReverseHoldEm', ->
  store = game = null
  builder = time = round = null

  beforeEach ->
    store = {}
    builder = new Fakes.TimeBuilder().withHour(1).withMinute(0).withSecond(0)
    time = new Fakes.FakeTimeProvider(builder.build())
    round = new Rounds.TimedRound(2, time)
    game = new ReverseHoldEm(store, round)
    game.playerStartingPoints = 25

  it 'basic gameplay with play, bet and settle rounds', ->
    game.play('chrismo', '112 234')
    game.play('romer', '555 964')
    game.play('sara', '219 008')
    game.play('glv', '134 998')
    game.play('bogdan', '774 208')
    expect(game.boardStore.romer.hand.name).toBe "Three of a Kind"
    expect(game.boardStore.chrismo.hand.name).toBe "Two Pair"
    game.holeDigits = ['5', '6']

    game.startBetting()

    expect(-> game.bet('woodall', '10')).toThrow "Can't bet if you haven't played."
    game.bet('bogdan', '3')
    game.bet('chrismo', '10') # demo auto-call
    game.bet('romer', '12')
    game.fold('sara')
    # player can call at this point now. It's potentially confusing if the player
    # has a strict expectation that call either means no higher bets can be made
    # or that the call command will be sticky, meaning it auto-adjusts to higher
    # bets. Play testing so far has shown players to be more confused over not
    # being able to issue this command at this point, presuming it would be
    # simply synonymous with "bet #{highest}".
    game.call('glv')

    game.settleUp()

    expect(-> game.bet('romer', '5')).toThrow "No new bets."
    game.call('glv')
    game.fold('bogdan')
    # chrismo does nothing and auto-calls

    game.finishRound()

    expect(game.winningHandResult.playerName).toBe 'romer'
    expect(game.winningHandResult.hand.name).toBe 'Full House'
    expect(game.playerStore[0].name).toBe 'chrismo'
    expect(game.playerStore[0].points).toBe 25 - 1 - 12
    expect(game.playerStore[1].name).toBe 'romer'
    expect(game.playerStore[1].points).toBe 25 - 1 - 12 + (1 + 1 + 1 + 1 + 1) + (12 + 12 + 12 + 3)
    expect(game.playerStore[2].name).toBe 'sara'
    expect(game.playerStore[2].points).toBe 25 - 1
    expect(game.playerStore[3].name).toBe 'glv'
    expect(game.playerStore[3].points).toBe 25 - 1 - 12
    expect(game.playerStore[4].name).toBe 'bogdan'
    expect(game.playerStore[4].points).toBe 25 - 1 - 3

    # folded players should be marked
    expect(game.boardStore.sara.folded).toBe true
    expect(game.boardStore.bogdan.folded).toBe true

    expect(game.playState.name).toBe 'play'

  it 'should show board during play', ->
    game.play('chrismo', '112234')
    expect(game.showBoard()).toBe (
          "Reverse Hold 'em       Hole: X X           Bet In: 1 min\n" +
          "                                                        \n" +
          "                                               POT / ALL\n" +
          "chrismo              112 234  Two Pair           1 /  24"
    )
    game.play('romer', ' 555  964')
    time.now = builder.withMinute(1).withSecond(0).build()
    time.execCallback()
    expect(game.showBoard()).toBe (
          "Reverse Hold 'em       Hole: X X         Settle In: soon\n" +
          "                 bet [xx] | call | fold                 \n" +
          "                                               POT / ALL\n" +
          "romer                555 964  Three of a Kind    1 /  24\n" +
          "chrismo              112 234  Two Pair           1 /  24"
    )
    game.holeDigits = ['5', '6']
    time.now = builder.withMinute(1).withSecond(30).build()
    time.execCallback()
    expect(game.showBoard()).toBe (
          "Reverse Hold 'em       Hole: X X          Flop In: 1 min\n" +
          "       call | fold  ||  ** auto-call in effect **       \n" +
          "                                               POT / ALL\n" +
          "romer                555 964  Three of a Kind    1 /  24\n" +
          "chrismo              112 234  Two Pair           1 /  24"
    )
    time.now = builder.withMinute(2).withSecond(0).build()
    time.execCallback()
    expect(game.showBoard()).toBe (
          "Reverse Hold 'em       Hole: 5 6           Winner: romer\n" +
          "                                                        \n" +
          "                                               POT / ALL\n" +
          "romer                555 964  Full House         0 /  26\n" +
          "chrismo              112 234  Six Straight       0 /  24"
    )

  it 'should respond to getStatus', ->
    game.getStatus()

  it 'should default new players with 25 points', ->
    game.play('chrismo', '112357')
    expect(game.playerStore.length).toBe 1
    expect(game.playerStore[0].name).toBe 'chrismo'

  it 'should persist players across games', ->
    game.play('chrismo', '112357')
    chrismo = game.playerStore[0]
    chrismo.points = 45
    expect(game.pot.players.length).toBe 1

    newRound = new Rounds.TimedRound(2, time)
    game = new ReverseHoldEm(store, newRound)
    expect(game.playerStore[0].name).toBe 'chrismo'
    expect(game.playerStore[0].points).toBe 45
    game.play('chrismo', '112357')
    expect(game.pot.players.length).toBe 1

  it 'should push notice of when time to bet', ->
    listener = new FakeListener()
    game.setListener(listener)
    game.play('chrismo', '112357')
    game.startBetting()
    expect(listener.msgs[0]).toBe "1 point ante."
    # not going to expect the remaining instructions - this test is
    # more for the push at all, not the content itself.
    expect(listener.msgs[2].substr(0, 30)).toBe "Hands are locked. Time to bet."

  it 'should allow direct funding to a player', ->
    game.play('chrismo', '112357')
    game.deal('sam')
    game.startBetting()
    game.bet('chrismo', '20')
    expect(game.playerStore[0].points).toBe 25 - 1 - 20
    game.fundPlayer('chrismo', '30')
    expect(game.playerStore[0].points).toBe 30

  it 'should declare a winner if everyone but one player folds'
  it 'should not allow a folded player to win', ->
    game.play('chrismo', '123456')
    game.play('romer', '112357')
    game.startBetting()
    expect(game.boardStore.romer.folded).toBe false
    expect(game.boardStore.chrismo.folded).toBe false
    game.fold('chrismo')
    expect(game.boardStore.chrismo.folded).toBe true
    expect(game.winningHandResult.playerName).toBe 'romer'

  it 'should end during betting if all players have bet or called to same max', ->
    game.play('woodall', '123456')
    game.play('sara', '111222')
    game.startBetting()
    expect(game.winningHandResult).toBe undefined
    game.bet('sara', '12')
    expect(game.winningHandResult).toBe undefined
    game.call('woodall')
    expect(game.winningHandResult.playerName).toBe 'sara'

  it 'should not allow a player with no points to play', ->
    expect(game.playerStore.length).toBe 0
    expect(game.vetPlayerForPlaying('chrismo')).toBe true
    game.play('chrismo', '112357')
    expect(game.playerStore[0].points).toBe 24
    game.playerStore[0].points = 0
    expect(-> game.vetPlayerForPlaying('chrismo')).toThrow "No dough, no show."

  it 'should not allow a player to call deal twice', ->
    game.deal('chrismo')
    expect(-> (game.deal('chrismo'))).toThrow 'You already have a hand, chrismo'

  it 'should not allow a player to call deal after play', ->
    game.play('chrismo', '112233')
    expect(-> (game.deal('chrismo'))).toThrow 'You already have a hand, chrismo'

  it 'should not allow a player to call play after deal', ->
    game.deal('chrismo')
    expect(-> (game.play('chrismo', '112233'))).toThrow 'You already have a hand, chrismo'

  it 'should properly order hands with same matchCount', ->
    # 4-oak and 3 pair have the same matchCount, so we decide
    # who wins by what works for other hands, simply sort by
    # digits hi-to-low and subtract.
    game.play('romer', '213333')
    game.play('chrismo', '443322')
    expect(game.handsInWinningOrder()[0].playerName).toBe 'chrismo'

  it 'is not that simple', ->
    # this incorrectly gives the win to woodall because sorted
    # the hands are 966555 and 666551. So, a bit of wishful
    # thinking with last night's commit.
    game.play('sara', '666 551')
    game.play('woodall', '555 669')
    expect(game.handsInWinningOrder()[0].playerName).toBe 'sara'

  it 'is really not that simple', ->
    # because this is only taking the submitted hand into account,
    # when hole cards are frequently included into making the winning hand.

  it 'should not allow a folded player to call', ->
    # it doesn't but it's a thrown err out of the pot
    # which is a little confusing to display there, but
    # it doesn't cause any problems.

  it 'should not show folded player amount in pot after round is over', ->
    # the player is not in the pot to have their totalBet
    # value reset to 0. So ... maybe the POT needs to track
    # folded players, instead of the game?

  it 'should not allow player with more points to bet more than an all in player', ->
    # a -> bet all in (20)
    # b -> bet 30 <= nope
    # unless there's a 3rd player putting up 30 as well

  it 'should not allow all in player to win more than they put in', ->
    # a -> bet 30
    # b -> all in (20)
    # b wins
    # b can't collect 30 from player a, only 20
    # http://en.wikipedia.org/wiki/Betting_in_poker#.22All_in.22

  it 'should hold first player plays on a new round until second player', ->
    # result = dealer.play('romer', '243243')
    # expect(result).toBe 'Need a second player to start the next round.'
    # result = dealer.play('romer', '555666')
    # expect(result).toBe 'Need a second player to start the next round.'
    # result = dealer.play('chrismo', '123123')
    # expect(result.join("\n")).toBe 'romer played 243243\nromer played 555666\nchrismo played 123123'
    # result = dealer.play('sara', '343434')
    # expect(result).toBe "sara played 343434"


class FakeListener
  constructor: ->
    @msgs = []

  onStatus: (msg) ->
    @msgs.push msg