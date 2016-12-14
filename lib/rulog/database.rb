module Rulog
  class Database
    DEBUG = false #true

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
      if fact.is_a?(RelationalFact) && fact.variables.any?
        OpenFactQuery.new(fact)
      else
        facts.any? do |f|
          f.name == fact.name
        end
      end
    end

    def match(fact, complement: false)
      p [ :match, fact: fact ] if DEBUG
      return query(fact) unless fact.variables.any?

      vars = fact.variables.map(&:name).map(&:to_sym)
      matches = object_combinations(vars.length).flat_map do |objs|
        ctx = vars.zip(objs).to_h
        subbed_fact = fact.substitute(ctx)
        if ((!complement && query(subbed_fact)) || (complement && !query(subbed_fact)))
          ctx
        end
      end.compact.uniq

      return false unless matches.any?
      matches
    end

    def query_rule(rule_name, args)
      p [ :query_rule, rule: rule_name, args: args ] if DEBUG
      (
        rule = detect_rule(rule_name)
        if args.any? { |arg| arg.is_a?(SimpleVariable) }
          # TODO needs to be OpenRuleQuery -- we also need OpenFactQuery
          OpenRuleQuery.new(rule, args)
        else
          rule_matches?(rule, args)
        end
      )
    end

    MAX_DEPTH = 4

    # need to query the clause as a 'whole' to pickup simple variables embedded inside...
    def rule_matches?(rule, objs, depth: MAX_DEPTH)
      p [ :rule_matches?, rule: rule.name, objs: objs, depth: depth ] if DEBUG
      return false if depth <= 0
      rule.clauses.each do |clause|
        resolved_clauses = clause.call(*objs)
        p [ :rule_matches?, rule: rule.name, objs: objs, depth: depth, resolved_clauses: resolved_clauses ] if DEBUG

        next if resolved_clauses.any? { |resolved| resolved == false }

        if resolved_clauses.any? { |resolved| resolved.is_a?(OpenQuery) }
          open = resolved_clauses.select { |resolved| resolved.is_a?(OpenQuery) }

          open_results = open.map do |open_query|
            if open_query.is_a?(OpenRuleQuery)
              p [ :open_rule, rule_query: open_query ] if DEBUG
              match_rule(open_query.rule.name, open_query.args, depth: depth - 1)
            elsif open_query.is_a?(OpenFactQuery)
              p [ :open_fact, fact_query: open_query ] if DEBUG
              match open_query.fact, complement: open_query.negated
            end
          end

          if open_results.uniq.length == 1
            return true if !!(open_results.uniq.first)
          else
            next if open_results.any? { |res| res == false }

            # try to find a 'common' solution (if there are lots of them...?)
            elements = open_results.flatten.uniq
            common_solution = elements.detect do |result_element|
              open_results.all? { |set| set.include?(result_element) }
            end

            return true if common_solution
          end
        else
          return true if resolved_clauses.all?
        end
      end

      false

    end

    def match_rule(rule_name, args, depth: MAX_DEPTH)
      p [ :match_rule, rule: rule_name, args: args, depth: depth ] if DEBUG
      return false if depth <= 0
      @cached_rule_matches ||= {}
      @cached_rule_matches[rule_name] ||= {}
      @cached_rule_matches[rule_name][args] ||= (
        rule = detect_rule(rule_name)
        matches = match_bindable_objects(args).flat_map do |objs|
          # check objs against args
          objs_match_args = args.zip(objs).all? do |arg, obj|
            arg.is_a?(SimpleObject) || arg.is_a?(Fixnum) || arg.is_a?(SimpleVariable) || (arg.respond_to?(:name) && obj.name == arg.name)
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
      (facts.flat_map(&:objects) + facts.select { |f| f.is_a?(RelationalFact) }).uniq
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

    def match_bindable_objects(slots)
      # okay, we need to narrow slots down to
      # just those with simple variables?
      free_slots = slots.select { |slot| slot.is_a?(SimpleVariable) }
      var_combos = object_combinations(free_slots.length)

      var_combos.map do |vars|
        # insert vars into open slots...
        slots.map do |slot|
          if slot.is_a?(SimpleVariable)
            vars.pop
          else
            slot
          end
        end
      end
    end

    def object_combinations(n=1)
      objects.repeated_permutation(n).to_a
    end

    # private
    def facts
      @facts ||= []
    end
  end
end
