Core = require('../../js/card-poker/core')
CardPoker = require('../../js/card-poker/hand')
_ = require('underscore')

describe 'GroupedHand', ->
  d = null

  beforeEach ->
    d = new Core.Deck()

  it 'should group ranks together to make fingerprint', ->
    hand = d.findAll(['2C', '2D'])
    expect(CardPoker.GroupedHand.groupings(hand)).toBe '2'

  it 'should strip single counts from fingerprint', ->
    hand = d.findAll(['2C', '2D', '3C'])
    expect(CardPoker.GroupedHand.groupings(hand)).toBe '2'

  it 'should generate correct two pair fingerprint', ->
    hand = d.findAll(['2C', '2D', '3C', '3D'])
    expect(CardPoker.GroupedHand.groupings(hand)).toBe '22'

  it 'should match one pair', ->
    gh = new CardPoker.GroupedHand('One Pair', '2')
    expect(gh.matches(new CardPoker.PlayerHand(d.findAll(['2C', '2D'])))).toBe true

  it 'should match two pair', ->
    gh = new CardPoker.GroupedHand('Two Pair', '22')
    hand = d.findAll(['2C', '2D', '4S', '4C'])
    expect(gh.matches(new CardPoker.PlayerHand(hand))).toBe true


describe 'StraightHand', ->
  d = null

  beforeEach ->
    d = new Core.Deck()

  it 'should get count of one intervals', ->
    hand = d.findAll(['2C', '3D', '5S', '6C', '4H'])
    expect(CardPoker.StraightHand.countOfOneIntervals(hand)).toBe 4

  it 'should match 5 straight', ->
    hand = d.findAll(['2C', '3D', '5S', '6C', '4H'])
    sh = new CardPoker.StraightHand('Straight')
    expect(sh.matches(new CardPoker.PlayerHand(hand))).toBe true

  it 'should match 5 straight face cards', ->
    hand = d.findAll(['AC', '10D', 'JS', 'QC', 'KH'])
    sh = new CardPoker.StraightHand('Straight')
    expect(sh.matches(new CardPoker.PlayerHand(hand))).toBe true


describe 'FlushHand', ->
