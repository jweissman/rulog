require 'rulog/version'

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
      "#{@relation.name}(#{@arguments.map(&:name).join(', ')})"
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
    attr_reader :rule, :args
    def initialize(rule, args)
      @rule = rule
      @args = args
    end
  end

  class Database
    def insert(fact)
      facts << fact
    end

    def learn(rule_name, &blk)
      @rules ||= {}
      @rules[rule_name] ||= Rule.new(rule_name)
      @rules[rule_name].add_clause(&blk)
    end

    def query(fact)
      facts.any? do |f|
        f.name == fact.name
      end
    end

    def match(fact)
      return query(fact) unless fact.variables.any?
      vars = fact.variables.map(&:name).map(&:to_sym)
      matches = objects.permutation.map { |perm| perm.take(vars.length) }.uniq.collect do |objs|
        ctx = vars.zip(objs).to_h
        subbed_fact = fact.substitute(ctx)
        if query(subbed_fact)
          ctx
        end
      end.compact.uniq

      return false unless matches.any?
      matches
    end

    def query_rule(rule_name, args)
      p [ :query_rule, rule: rule_name, args: args ]
      rule = detect_rule(rule_name)
      if args.any? { |arg| arg.is_a?(SimpleVariable) }
        # maybe return a 'canned' form
        OpenQuery.new(rule, args)
      else
        rule_matches?(rule, args)
      end
    end

    # need to query the clause as a 'whole' to pickup simple variables embedded inside...
    def rule_matches?(rule, objs)
      p [ :rule_matches, rule: rule.name, objs: objs ]
      rule.clauses.detect do |clause|
        resolved_clauses = clause.call(objs)
        if resolved_clauses.any? { |resolved| resolved.is_a?(OpenQuery) }
          open, closed = resolved_clauses.partition { |resolved| resolved.is_a?(OpenQuery) }
          next unless closed.all?

          open_results = open.map do |open_query|
            match_rule(open_query.rule.name, open_query.args)
          end

          return true if open_results.uniq.length == 1
        else
          return true if resolved_clauses.all?
        end
      end
    end

    def match_rule(rule_name, args)
      p [ :match_rule, rule: rule_name, args: args ]
      rule = detect_rule(rule_name)
      # matches = objects.permutation.collect do |objs|
      matches = objects.permutation.map { |perm| perm.take(args.length) }.uniq.collect do |objs|
        # check objs against args
        objs_match_args = args.zip(objs).all? do |(arg, obj)|
          arg.is_a?(SimpleVariable) || obj.name == arg.name
        end

        if objs_match_args && rule_matches?(rule, objs)
          # okay, this is a valid application of this rule! hand back var args
          args.zip(objs).select do |(k,_)|
            k.is_a?(SimpleVariable)
          end.compact.inject({}) do |hsh,(key,value)|
            hsh[key.name.to_sym] = value; hsh
          end
        end
      end.compact.uniq

      return false unless matches.any?
      matches
    end

    def relations
      facts.select { |f| f.is_a?(RelationalFact) }.map(&:relation).uniq
    end

    def objects
      facts.flat_map(&:objects).uniq
    end

    def self.current
      @current ||= Database.new
    end

    def has_rule?(rule_name)
      !!detect_rule(rule_name)
      # rules.any? { |rule| rule.name == rule_name }
    end

    def detect_rule(rule_name)
      @rules ||= {}
      @rules[rule_name]
      # @rules.detect { |rule| rule.name == rule_name }
    end

    private
    def facts
      @facts ||= []
    end
  end

  module DSL
    def method_missing(meth, *args, &blk)
      if meth.to_s.end_with?('!')
        if block_given? # we have a rule...
          rule_name = meth.to_s.chomp('!')
          # rule = Rule.new(, &blk)
          Database.current.learn rule_name, &blk
          true
        else
          fact = if args.any?
            # dealing with a relation
            relation = Relation.named(meth.to_s.chomp('!'))
            RelationalFact.new(relation, arguments: args)
          else
            # insert a fact
            SimpleFact.new(meth.to_s.chomp('!'))
          end

          Database.current.insert fact
          true
        end
      elsif meth.to_s.end_with?('?')
        meth_name = meth.to_s.chomp('?')
        if Database.current.has_rule?(meth_name)
          Database.current.query_rule meth_name, args
        else
          # run a query
          fact = if args.any? # if args are vars we may need to match instead?
            relation = Relation.named(meth_name)
            RelationalFact.new(relation, arguments: args)
          else
            SimpleFact.new(meth_name)
          end

          Database.current.query fact
        end
      else
        if args.any?
          if Database.current.has_rule?(meth.to_s)
            Database.current.match_rule meth.to_s, args
          else
            relation = Relation.named(meth.to_s)
            fact = RelationalFact.new(relation, arguments: args)

            # assume we're being asked to match a fact here
            Database.current.match fact
          end
        else
          if meth.to_s.match(/^_/)
            var = SimpleVariable.named(meth.to_s)
            var
          else
            rule = Database.current.detect_rule(meth.to_s)
            return rule if rule

            # see if we may be referening a relation?
            relation = Database.current.relations.detect { |rel| rel.name == meth.to_s }
            return relation if relation

            # assume we're building a simple object
            object = SimpleObject.named(meth.to_s)
            object
          end
        end
      end
    end
  end
end
