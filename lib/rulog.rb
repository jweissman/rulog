require 'rulog/version'
require 'rulog/database'
require 'rulog/dsl'

module Rulog
  class SimpleFact
    attr_reader :name
    def initialize(name)
      @name = name
    end

    def objects; [] end
    def inspect; @name end
  end

  class SimpleVariable
    attr_reader :name

    def self.named(name)
      @vars ||= {}
      @vars[name] ||= new(name)
    end

    def initialize(name)
      @name = name
    end

    def inspect; @name end
  end

  class SimpleObject
    attr_reader :name

    def self.named(name)
      @objects ||= {}
      @objects[name] ||= new(name)
    end

    def initialize(name)
      @name = name
    end

    def inspect; @name end
  end

  class Relation
    attr_reader :name

    def self.named(name)
      @relations ||= {}
      @relations[name] ||= new(name)
    end

    def initialize(name)
      @name = name
    end

    def inspect; @name end
  end

  class RelationalFact
    attr_reader :relation
    def initialize(relation, arguments:)
      @relation = relation
      @arguments = arguments
    end

    def objects
      @arguments.select do |arg|
        arg.is_a?(SimpleObject)
      end
    end

    def variables
      @arguments.select do |arg|
        arg.is_a?(SimpleVariable)
      end
    end

    def substitute(mapping)
      subbed_args = @arguments.map do |arg| #variable, object|
        if mapping.has_key?(arg.name.to_sym)
          mapping[arg.name.to_sym]
        else
          arg
        end
      end
      RelationalFact.new(@relation, arguments: subbed_args)
    end

    def name
      "#{@relation.name}(#{@arguments.flatten.join(', ')})"
    end
  end

  class Rule
    attr_reader :name
    def initialize(name)
      @name = name
      @blocks = []
    end

    def add_clause(&blk)
      @blocks << blk
    end

    def clauses; @blocks end
  end

  class OpenQuery
  end

  class OpenFactQuery < OpenQuery
    attr_reader :fact, :negated # relation, :args
    def initialize(fact, negated: false) #relation, args)
      @fact = fact
      @negated = negated
    end

    def ~
      self.class.new(@fact, negated: !@negated)
    end
  end

  class OpenRuleQuery < OpenQuery
    attr_reader :rule, :args
    def initialize(rule, args)
      @rule = rule
      @args = args
    end
  end

  def self.write(*args)
    message = message_from(args)
    @terminal ||= []
    @terminal << message
    puts message
    true
  end

  def self.messages_written
    @terminal ||= []
  end

  def self.reset!
    @terminal = []
    Database.current.clear!
  end

  private
  def self.message_from(args)
    msg = ""
    args.map do |s|
      if s.respond_to?(:name)
        msg += s.name
      else
        msg += s
      end
    end
    msg += "."
    msg
  end
end
