module Rulog
  class Database
    def clear!
      @rules = {}
      @facts = []
    end

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
      matches = object_combinations(vars.length).flat_map do |objs|
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
        OpenQuery.new(rule, args)
      else
        rule_matches?(rule, args)
      end
    end

    MAX_DEPTH = 16

    # need to query the clause as a 'whole' to pickup simple variables embedded inside...
    def rule_matches?(rule, objs, depth: MAX_DEPTH)
      p [ :rule_matches?, rule: rule.name, objs: objs, depth: depth ]
      return false if depth <= 0
      rule.clauses.each do |clause|
        resolved_clauses = clause.call(*objs)
        if resolved_clauses.any? { |resolved| resolved.is_a?(OpenQuery) }
          open, closed = resolved_clauses.partition { |resolved| resolved.is_a?(OpenQuery) }
          next unless closed.all?

          open_results = open.map do |open_query|
            match_rule(open_query.rule.name, open_query.args, depth: depth - 1)
          end

          if open_results.uniq.length == 1
            # binding.pry
            return true if !!(open_results.uniq.first)
          end
        else
          return true if resolved_clauses.all?
        end
      end

      false
    end

    def match_rule(rule_name, args, depth: MAX_DEPTH)
      p [ :match_rule, rule: rule_name, args: args, depth: depth ]
      return false if depth <= 0
      @rule_matches ||= {}
      @rule_matches[rule_name] ||= {}
      @rule_matches[rule_name][args] ||= (

        rule = detect_rule(rule_name)

        matches = object_combinations(args.length).flat_map do |objs|
          # check objs against args
          objs_match_args = args.zip(objs).all? do |arg, obj|
            # begin
            arg.is_a?(SimpleVariable) || (arg.respond_to?(:name) && obj.name == arg.name)
            # rescue => ex
            #   binding.pry
            # end
          end

          if objs_match_args && rule_matches?(rule, objs, depth: depth-1)
            # okay, this is a valid application of this rule! hand back var args
            args.zip(objs).select do |(k,_)|
              k.is_a?(SimpleVariable)
            end.compact.inject({}) do |hsh,(key,value)|
              hsh[key.name.to_sym] = value; hsh
            end
          end
        end.compact.uniq

        if matches.any? then matches else false end
      )
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
    end

    def detect_rule(rule_name)
      @rules ||= {}
      @rules[rule_name]
    end

    def object_combinations(n=1)
      objects.repeated_permutation(n).to_a
    end

    private
    def facts
      @facts ||= []
    end
  end
end
