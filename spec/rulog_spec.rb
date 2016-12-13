require 'spec_helper'
require 'rulog'

RSpec.describe Rulog do
  let(:database) do
    Database.new
  end

  let(:it_is_sunny) do
    SimpleFact.new 'sunny'
  end

  let(:logic_programming_is_cool) do
    SimpleFact.new 'logic programming is cool'
  end

  it 'should accept facts' do
    database.insert( it_is_sunny )
    expect( database.query( it_is_sunny ) ).to be_truthy

    database.insert( logic_programming_is_cool )
    expect( database.query( logic_programming_is_cool )).to be_truthy
  end

  let(:alice) { SimpleObject.new("Alice") }
  let(:bob)   { SimpleObject.new("Bob") }

  let(:likes) do
    Relation.new("likes")
  end

  let(:bob_likes_alice) do
    RelationalFact.new(likes, arguments: [bob, alice])
  end

  let(:alice_likes_bob) do
    RelationalFact.new(likes, arguments: [alice, bob])
  end

  it 'should accept relations' do
    database.insert( bob_likes_alice )
    expect( database.query( bob_likes_alice ) ).to be_truthy
    expect( database.query( alice_likes_bob ) ).to be_falsy
  end

  it 'should match bound slots' do
    database.insert( alice_likes_bob )
    one = SimpleVariable.named('_one')
    two = SimpleVariable.named('_two')

    expect(database.match_bindable_objects([ alice, one, 1 ])).to eq([
      [ alice, alice, 1 ],
      [ alice, bob, 1 ]
    ])

    expect(database.match_bindable_objects([ one, two ])).to eq([
      [ alice, alice ],
      [ bob, alice ],
      [ alice, bob ],
      [ bob, bob ]
    ])

    expect(database.match_bindable_objects([ 1, one, two ])).to eq([
      [ 1, alice, alice ],
      [ 1, bob, alice ],
      [ 1, alice, bob ],
      [ 1, bob, bob ]
    ])
  end
end

RSpec.describe DSL do
  before(:each) do
    Rulog.reset! # clear db and output buffer
  end

  it 'should permit creating facts, relations and queries ad hoc' do
    extend DSL

    # tell db facts with '!'
    sunny!
    expect(sunny?).to be_truthy

    logic_programming_is_cool!
    expect(logic_programming_is_cool?).to be_truthy
  end

  it 'should permit constructing ad hoc relations' do
    extend DSL

    # build predicates
    likes!(mary, james)

    # insert facst with predicates without a '!'
    likes! alice, bob

    expect( likes?(alice, bob) ).to be_truthy
    expect( likes?(mary, james) ).to be_truthy

    # expect(Database.current.relations.map(&:name)).to eq %w[ likes ]

    expect( likes(mary, _who) ).to eq([{_who: james}])
  end

  it 'should permit building rules' do
    extend DSL

    likes!(mary, james)
    likes!(james, mary)
    likes!(mary, alice)

    friends! { |x,y| [ likes?(x,y), likes?(y,x) ] }

    expect( friends?(mary, james) ).to be_truthy
    expect( friends?(mary, alice) ).to be_falsy
    expect( friends?(james, tom) ).to be_falsy

    expect( friends(mary, _who) ).to eq([{_who: james}])
    expect( friends(james, _who) ).to eq([{_who: mary}])
    expect( friends(alice, _who) ).to eq(false)
  end

  it 'should permit inferences from rules' do
    extend DSL
    mother!(alice,lea)
    mother!(john,julia)
    mother!(lea,alberta)
    father!(james,alfred)
    father!(lea,john)

    parent! { |x,y| [ mother?(x,y) ] }
    parent! { |x,y| [ father?(x,y) ] }

    grandparent! { |x,y| [ parent?(x,_z), parent?(_z,y) ] }

    expect( grandparent(alice, _who) ).to eq([{_who: john}, {_who: alberta}])
    expect( grandparent?(alice, john) ).to be_truthy
  end

  it 'should solve coloring problems' do
    extend DSL
    color!(red)
    color!(blue)

    neighbors! { |x,y| [ color(x), color(y), x != y ] }

    country! do |al, fl, ga, tn, ms|
      [
        neighbors?(al, fl),
        neighbors?(al, ga),
        neighbors?(al, tn),
        neighbors?(al, ms),
        neighbors?(fl, ga),
        neighbors?(tn, ga),
        neighbors?(tn, ms),
      ]
    end

    coloring = country( _al, _fl, _ga, _tn, _ms )
    expect( coloring ).to eq(false)

    color!(orange)
    recoloring = country( _al, _fl, _ga, _tn, _ms )
    expect( recoloring.first ).to eq({_al: orange, _fl: blue, _ga: red, _tn: blue, _ms: red})
    expect( recoloring.count ).to eq(6)
  end

  it 'should solve syllogisms' do
    extend DSL
    human! socrates
    mortal! { |x| [ human?(x) ] }
    expect( mortal?(socrates) ).to eq(true)
    expect( mortal(_who) ).to eq([{ _who: socrates }])
  end

  it 'should solve recursive relational problems' do
    extend DSL
    teacher!(socrates, plato)
    teacher!(cratylus, plato)
    teacher!(plato, aristotle)
    teacher!(aristotle, alexander)

    expect( teacher(_who, plato) ).to eq([ {_who: socrates}, {_who: cratylus} ])

    disciple! { |x,y| [ teacher?(y,x) ] }
    taught!   { |x| [ disciple?(x,_w) ] }

    expect( taught?(socrates)).to eq(false)

    follower! { |x,y| [ disciple?(x,y) ] }
    follower! { |x,y| [ disciple?(x,_z),
                        follower?(_z,y) ] }

    expect( follower?(aristotle, socrates) ).to eq(true)
    expect( follower(_who, socrates) ).to eq([{_who: plato}, {_who: aristotle}])

    # deriving these takes longer...
    expect( follower(aristotle, _who) ).to eq([{_who: socrates}, {_who: plato}, {_who: cratylus}])
    expect( follower(_who, aristotle) ).to eq([{_who: alexander}])
    expect( follower?(cratylus, aristotle) ).to eq(false)
  end

  it 'should solve towers of hanoi' do
    extend DSL

    move_one! { |x,y| [ Rulog.write("Move top disk from ", x, " to ", y) ] }

    move! do |n, x, y, z|
      if n > 1
        [
          move(n-1, x, z, y),
          move_one(x,y),
          move(n-1, z, y, x)
        ]
      else
        [
          move_one(x,y)
        ]
      end
    end

    peg!(left)
    peg!(center)
    peg!(right)

    expect( move?(3, left, center, right) ).to eq(true)
    expect( Rulog.messages_written.count ).to eq(7)
    expect( Rulog.messages_written ).to eq(
      ["Move top disk from left to center.",
       "Move top disk from left to right.",
       "Move top disk from center to right.",
       "Move top disk from left to center.",
       "Move top disk from right to left.",
       "Move top disk from right to center.",
       "Move top disk from left to center."]
    )
  end
end
