module Rulog
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
            # p [ :match_rule!, method: meth.to_s, args: args ]
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
            if rule
              if block_given?
                # we are being given a new rule defn
                Database.current.learn meth.to_s, &blk
              else
                return rule
              end
            end

            # see if we may be referening a relation?
            relation = Database.current.relations.detect { |rel| rel.name == meth.to_s }
            return relation if relation

            if block_given?
              # definitely building a rule
              Database.current.learn meth.to_s, &blk
              true
            else
              # assume we're building a simple object
              object = SimpleObject.named(meth.to_s)
              object
            end
          end
        end
      end
    end
  end
end
