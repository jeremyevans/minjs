module Minjs
  module Exp
    #
    # Primary Expressions
    # 11.1
    #
    def primary_exp(lex, context, options)
      @logger.debug "*** primary_exp"

      if lex.eql_lit?(ECMA262::ID_THIS)
      @logger.debug "*** primary_exp => this"
        return ECMA262::ID_THIS
      end
      # (exp)
      if lex.eql_lit?(ECMA262::PUNC_LPARENTHESIS)
        if a=exp(lex, context, options) and lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS)
          @logger.debug "*** primary_exp => ()"
          return ECMA262::ExpParen.new(a)
        else
          raise ParseError.new("no `)' at end of expression", lex)
        end
      end

      t = identifier(lex, context) ||
          literal(lex, context) ||
          array_literal(lex, context, options) ||
          object_literal(lex, context, options)

      @logger.debug {
        "*** primary_exp => #{t ? t.to_js : t}"
      }
      t
    end

    #
    # 11.1.2
    #
    def identifier(lex, context)
      a = lex.next_lit(nil)
      if a.kind_of? ECMA262::IdentifierName and !a.reserved?
        lex.fwd_lit(nil)
        a.context = context
        a
      else
        nil
      end
    end

    #
    # 11.1.4
    #
    def array_literal(lex, context, options)
      return nil unless lex.eql_lit?(ECMA262::PUNC_LSQBRAC)
      t = []
      lex.eval_lit {
        while true
          if lex.eql_lit?(ECMA262::PUNC_COMMA)
            t.push(nil)
          elsif lex.eql_lit?(ECMA262::PUNC_RSQBRAC)
            break
          elsif a = assignment_exp(lex, context, {})
            t.push(a)
            lex.eql_lit?(ECMA262::PUNC_COMMA)
          else
            raise ParseError.new("no `]' end of array", lex)
          end
        end
        ECMA262::ECMA262Array.new(t)
      }
    end
    #
    # 11.1.5
    #
    def object_literal(lex, context, options)
      return nil unless lex.eql_lit?(ECMA262::PUNC_LCURLYBRAC)
      lex.eval_lit {
        if lex.eql_lit?(ECMA262::PUNC_RCURLYBRAC)
          next ECMA262::ECMA262Object.new([])
        end
        if h=property_name_and_value_list(lex, context, options)
          ECMA262::ECMA262Object.new(h)
        else
          raise ParseError.new("no `}' end of object", lex)
        end
      }
    end

    #
    # name: exp
    # get name(){funcbody}
    # set name(args){funcbody}
    #
    def property_name_and_value_list(lex, context, options)
      lex.eval_lit{
        h = []
        while !lex.eof?
          if lex.eql_lit?(ECMA262::PUNC_RCURLYBRAC)
            break
          end
          lex.eval_lit{
            if lex.match_lit?(ECMA262::ID_GET) and a=property_name(lex, context) and lex.eql_lit?(ECMA262::PUNC_LPARENTHESIS) and lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS) and lex.eql_lit?(ECMA262::PUNC_LCURLYBRAC) and b=func_body(lex, context) and lex.eql_lit?(ECMA262::PUNC_RCURLYBRAC)
              h.push([a, ECMA262::StFunc.new(context, ECMA262::ID_GET, [], b, :getter => true)])
            elsif lex.match_lit?(ECMA262::ID_SET) and a=property_name(lex, context) and lex.eql_lit?(ECMA262::PUNC_LPARENTHESIS) and arg=property_set_parameter_list(lex, context) and lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS) and lex.eql_lit?(ECMA262::PUNC_LCURLYBRAC) and b=func_body(lex, context) and lex.eql_lit?(ECMA262::PUNC_RCURLYBRAC)
              h.push([a, ECMA262::StFunc.new(context, ECMA262::ID_SET, arg, b, :setter => true)])
            else
              nil
            end
          } or lex.eval_lit{
            a=property_name(lex, context) and lex.eql_lit?(ECMA262::PUNC_COLON) and b=assignment_exp(lex, context, options)
            h.push([a, b])
          }

          if lex.eql_lit?(ECMA262::PUNC_COMMA)
            break if lex.eql_lit?(ECMA262::PUNC_RCURLYBRAC)
          elsif lex.eql_lit?(ECMA262::PUNC_RCURLYBRAC)
            break
          else
            raise ParseError.new("no `}' end of object", lex)
          end
        end
        h
      }
    end

    def property_name(lex, context)
      lex.eval_lit {
        a = lex.fwd_lit(nil)
        if a.kind_of?(ECMA262::ECMA262String)
          a
        elsif a.kind_of?(ECMA262::IdentifierName)
          ECMA262::ECMA262String.new(a.to_js)
        elsif a.kind_of?(ECMA262::ECMA262Numeric)
          a
        else
          nil
        end
      }
    end

    def property_set_parameter_list(lex, context)
      lex.eval_lit {
        a = lex.fwd_lit(nil)
        if a.kind_of?(ECMA262::IdentifierName) and !a.reserved?
          [a]
        else
          nil
        end
      }
    end

    #
    # 11.2
    #
    def left_hand_side_exp(lex, context, options)
      @logger.debug "*** left_hand_side_exp"

      t = lex.eval_lit{
        call_exp(lex, context, options)
      } || lex.eval_lit{
        new_exp(lex, context, options)
      }
      @logger.debug{
        "*** left_hand_side_exp => #{t ? t.to_js: t}"
      }
      t
    end

    def new_exp(lex, context, options)
      lex.eval_lit{
        if lex.eql_lit?(ECMA262::ID_NEW)
          if a=new_exp(lex, context, options)
            ECMA262::ExpNew.new(a, nil)
          else
            raise ParseError.new("unexpceted token", lex)
          end
        else
          nil
        end
      } or lex.eval_lit{
        member_exp(lex, context, options)
      }
    end

    #
    # call
    #
    # member_exp arguments
    #
    # call_exp arguments
    # call_exp [exp]
    # call_exp . identifier_name
    #
    #
    def call_exp(lex, context, options)
      a = lex.eval_lit{
        if f = member_exp(lex, context, options)
          if b = arguments(lex, context, options)
            ECMA262::ExpCall.new(f, b)
          else
            f
          end
        else
          nil
        end
      }
      return nil if a.nil?

      t = a

      lex.eval_lit{
        while true
          if b=arguments(lex, context, options)
            t = ECMA262::ExpCall.new(t, b)
          elsif lex.eql_lit?(ECMA262::PUNC_LSQBRAC)
            if b=exp(lex, context, options) and lex.eql_lit?(ECMA262::PUNC_RSQBRAC)
              t = ECMA262::ExpPropBrac.new(t, b)
            else
              raise ParseError.new("unexpceted token", lex)
            end
          elsif lex.eql_lit?(ECMA262::PUNC_PERIOD)
            if (b=lex.fwd_lit(nil)).kind_of?(ECMA262::IdentifierName)
              t = ECMA262::ExpProp.new(t, b)
            else
              raise ParseError.new("unexpceted token", lex)
            end
          else
            break
          end
        end
        t
      } or a
    end

    #
    # member_exp
    #  primary_exp
    #  function_exp
    #  new member_exp arguments
    #
    #  member_exp[exp]
    #  member_exp.identifier_name #prop(a,b)
    #
    def member_exp(lex, context, options)
      a = lex.eval_lit {
        primary_exp(lex, context, options)
      } || lex.eval_lit {
        func_exp(lex, context)
      } || lex.eval_lit {
        if lex.eql_lit?(ECMA262::ID_NEW) and a=member_exp(lex, context, options) and b=arguments(lex, context, options)
          ECMA262::ExpNew.new(a, b)
        else
          nil
        end
      }
      return nil if a.nil?

      t = a

      lex.eval_lit {
        while true
          if lex.eql_lit?(ECMA262::PUNC_LSQBRAC)
            if b=exp(lex, context, options) and lex.eql_lit?(ECMA262::PUNC_RSQBRAC)
              t = ECMA262::ExpPropBrac.new(t, b)
            else
              raise ParseError.new("unexpceted token", lex)
            end
          elsif lex.eql_lit?(ECMA262::PUNC_PERIOD)
            if (b=lex.fwd_lit(nil)).kind_of?(ECMA262::IdentifierName)
              t = ECMA262::ExpProp.new(t, b)
            else
              raise ParseError.new("unexpceted token", lex)
            end
          else
            break
          end
        end
        t
      } or a
    end

    def arguments(lex, context, options)
      lex.eval_lit{
        return nil if lex.eql_lit?(ECMA262::PUNC_LPARENTHESIS).nil?
        next [] if lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS)
        args = []
        while true
          if t = assignment_exp(lex, context, options)
            args.push(t)
          else
            return
          end
          if lex.eql_lit?(ECMA262::PUNC_COMMA)
            ;
          elsif lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS)
            break
          else
            return
          end
        end
        args
      }
    end
    #
    # 11.3
    #
    def postfix_exp(lex, context, options)
      t = lex.eval_lit{
        a = left_hand_side_exp(lex, context, options)
        return nil if a.nil?
        if punc = (lex.eql_lit_nolt?(ECMA262::PUNC_INC) ||
                   lex.eql_lit_nolt?(ECMA262::PUNC_DEC))
          if punc == ECMA262::PUNC_INC
            ECMA262::ExpPostInc.new(a)
          else
            ECMA262::ExpPostDec.new(a)
          end
        else
          a
        end
      }
      t
    end

    #
    # 11.4
    #
    def unary_exp(lex, context, options)
      lex.eval_lit{
        if punc = (lex.eql_lit?(ECMA262::ID_DELETE) ||
                   lex.eql_lit?(ECMA262::ID_VOID) ||
                   lex.eql_lit?(ECMA262::ID_TYPEOF) ||
                   lex.eql_lit?(ECMA262::PUNC_INC) ||
                   lex.eql_lit?(ECMA262::PUNC_DEC) ||
                   lex.eql_lit?(ECMA262::PUNC_ADD) ||
                   lex.eql_lit?(ECMA262::PUNC_SUB) ||
                   lex.eql_lit?(ECMA262::PUNC_NOT) ||
                   lex.eql_lit?(ECMA262::PUNC_LNOT))
          a = unary_exp(lex, context, options)
          if a.nil?
            raise ParseError.new("unexpceted token", lex)
          elsif punc == ECMA262::PUNC_INC
            ECMA262::ExpPreInc.new(a)
          elsif punc == ECMA262::PUNC_DEC
            ECMA262::ExpPreDec.new(a)
          elsif punc == ECMA262::PUNC_ADD
            ECMA262::ExpPositive.new(a)
          elsif punc == ECMA262::PUNC_SUB
            ECMA262::ExpNegative.new(a)
          elsif punc == ECMA262::PUNC_NOT
            ECMA262::ExpBitwiseNot.new(a)
          elsif punc == ECMA262::PUNC_LNOT
            ECMA262::ExpLogicalNot.new(a)
          elsif punc.respond_to?(:val)
            if punc.val == :delete
              ECMA262::ExpDelete.new(a)
            elsif punc.val == :void
              ECMA262::ExpVoid.new(a)
            elsif punc.val == :typeof
              ECMA262::ExpTypeof.new(a)
            end
          end
        end
      } || lex.eval_lit{
        postfix_exp(lex, context, options)
      }
    end

    #
    # 11.5
    #
    def multiplicative_exp(lex, context, options)
      lex.eval_lit {
        a = unary_exp(lex, context, options)
        next nil if !a
        t = a
        while punc = lex.eql_lit?(ECMA262::PUNC_MUL) ||
                     lex.eql_lit?(ECMA262::PUNC_DIV, :hint => :div) ||
                     lex.eql_lit?(ECMA262::PUNC_MOD)

          if b = unary_exp(lex, context, options)
            if punc == ECMA262::PUNC_MUL
              t = ECMA262::ExpMul.new(t, b)
            elsif punc == ECMA262::PUNC_DIV
              t = ECMA262::ExpDiv.new(t, b)
            else
              t = ECMA262::ExpMod.new(t, b)
            end
          else
            raise ParseError.new("unexpceted token", lex)
          end
        end
        t
      }
    end

    #
    # 11.6
    #
    def additive_exp(lex, context, options)
      lex.eval_lit {
        a = multiplicative_exp(lex, context, options)
        next nil if !a

        t = a
        while punc = lex.eql_lit?(ECMA262::PUNC_ADD) || lex.eql_lit?(ECMA262::PUNC_SUB)
          if b = multiplicative_exp(lex, context, options)
            if punc == ECMA262::PUNC_ADD
              t = ECMA262::ExpAdd.new(t, b)
            else
              t = ECMA262::ExpSub.new(t, b)
            end
          else
            raise ParseError.new("unexpceted token", lex)
          end
        end

        t
      }
    end
    #
    # 11.7
    def shift_exp(lex, context, options)
      lex.eval_lit {
        a = additive_exp(lex, context, options)
        next nil if !a

        t = a
        while punc = lex.eql_lit?(ECMA262::PUNC_LSHIFT) ||
                     lex.eql_lit?(ECMA262::PUNC_RSHIFT) ||
                     lex.eql_lit?(ECMA262::PUNC_URSHIFT)
          if b = additive_exp(lex, context, options)
            if punc == ECMA262::PUNC_LSHIFT
              t = ECMA262::ExpLShift.new(t, b)
            elsif punc == ECMA262::PUNC_RSHIFT
              t = ECMA262::ExpRShift.new(t, b)
            elsif punc == ECMA262::PUNC_URSHIFT
              t = ECMA262::ExpURShift.new(t, b)
            end
          else
            raise ParseError.new("unexpceted token", lex)
          end
        end
        t
      }
    end
    #
    #
    # 11.8
    #
    def relational_exp(lex, context, options)
      lex.eval_lit {
        a = shift_exp(lex, context, options)
        next nil if !a

        t = a
        while (punc = lex.eql_lit?(ECMA262::PUNC_LT) || lex.eql_lit?(ECMA262::PUNC_GT) ||
                      lex.eql_lit?(ECMA262::PUNC_LTEQ) || lex.eql_lit?(ECMA262::PUNC_GTEQ) ||
                      lex.eql_lit?(ECMA262::ID_INSTANCEOF) || (!options[:no_in] && lex.eql_lit?(ECMA262::ID_IN)))
          if b = shift_exp(lex, context, options)
            if punc == ECMA262::PUNC_LT
              t = ECMA262::ExpLt.new(t, b)
            elsif punc == ECMA262::PUNC_GT
              t = ECMA262::ExpGt.new(t, b)
            elsif punc == ECMA262::PUNC_LTEQ
              t = ECMA262::ExpLtEq.new(t, b)
            elsif punc == ECMA262::PUNC_GTEQ
              t = ECMA262::ExpGtEq.new(t, b)
            elsif punc.val == :instanceof
              t = ECMA262::ExpInstanceOf.new(t, b)
            elsif !options[:no_in] and punc.val == :in
              t = ECMA262::ExpIn.new(t, b)
            else
            end
          else
            raise ParseError.new("unexpceted token", lex)
          end
        end

        t
      }
    end
    #
    #
    # 11.9
    # a == b
    # a != b
    # a === b
    # a !== b
    #
    def equality_exp(lex, context, options)
      lex.eval_lit {
        a = relational_exp(lex, context, options)
        next nil if !a

        t = a
        while punc = lex.eql_lit?(ECMA262::PUNC_EQ) ||
                     lex.eql_lit?(ECMA262::PUNC_NEQ) ||
                     lex.eql_lit?(ECMA262::PUNC_SEQ) ||
                     lex.eql_lit?(ECMA262::PUNC_SNEQ)
          if b = relational_exp(lex, context, options)
            if punc == ECMA262::PUNC_EQ
              t = ECMA262::ExpEq.new(t, b)
            elsif punc == ECMA262::PUNC_NEQ
              t = ECMA262::ExpNotEq.new(t, b)
            elsif punc == ECMA262::PUNC_SEQ
              t = ECMA262::ExpStrictEq.new(t, b)
            elsif punc == ECMA262::PUNC_SNEQ
              t = ECMA262::ExpStrictNotEq.new(t, b)
            end
          else
            raise ParseError.new("unexpceted token", lex)
          end
        end

        t
      }
    end

    #
    # 11.10
    # a & b
    #
    def bitwise_and_exp(lex, context, options)
      lex.eval_lit {
        a = equality_exp(lex, context, options)
        next nil if !a

        t = a
        while punc = lex.eql_lit?(ECMA262::PUNC_AND)
          if b = equality_exp(lex, context, options)
            t = ECMA262::ExpAnd.new(t, b)
          else
            raise ParseError.new("unexpceted token", lex)
          end
        end

        t
      }
    end

    #
    # a ^ b
    #
    def bitwise_xor_exp(lex, context, options)
      lex.eval_lit {
        a = bitwise_and_exp(lex, context, options)
        next nil if !a

        t = a
        while punc = lex.eql_lit?(ECMA262::PUNC_XOR)
          if b = bitwise_and_exp(lex, context, options)
            t = ECMA262::ExpXor.new(t, b)
          else
            raise ParseError.new("unexpceted token", lex)
          end
        end

        t
      }
    end

    #
    # a | b
    #
    def bitwise_or_exp(lex, context, options)
      lex.eval_lit {
        a = bitwise_xor_exp(lex, context, options)
        next nil if !a

        t = a
        while punc = lex.eql_lit?(ECMA262::PUNC_OR)
          if b = bitwise_xor_exp(lex, context, options)
            t = ECMA262::ExpOr.new(t, b)
          else
            raise ParseError.new("unexpceted token", lex)
          end
        end

        t
      }
    end
    #
    # 11.11
    # a && b
    #
    def logical_and_exp(lex, context, options)
      lex.eval_lit {
        a = bitwise_or_exp(lex, context, options)
        next nil if !a

        t = a
        while punc = lex.eql_lit?(ECMA262::PUNC_LAND)
          if b = bitwise_or_exp(lex, context, options)
            t = ECMA262::ExpLogicalAnd.new(t, b)
          else
            raise ParseError.new("unexpceted token", lex)
          end
        end

        t
      }
    end

    def logical_or_exp(lex, context, options)
      lex.eval_lit {
        a = logical_and_exp(lex, context, options)
        next nil if !a

        t = a
        while punc = lex.eql_lit?(ECMA262::PUNC_LOR)
          if b = logical_and_exp(lex, context, options)
            t = ECMA262::ExpLogicalOr.new(t, b)
          else
            raise ParseError.new("unexpceted token", lex)
          end
        end

        t
      }
    end
    #
    # 11.12
    # a ? b : c
    #
    def cond_exp(lex, context, options)
      t = lex.eval_lit {
        a = logical_or_exp(lex, context, options)
        next nil if !a

        if lex.eql_lit?(ECMA262::PUNC_CONDIF)
          if b=assignment_exp(lex, context, options) and lex.eql_lit?(ECMA262::PUNC_COLON) and c=assignment_exp(lex, context, options)
            ECMA262::ExpCond.new(a, b, c)
          else
            raise ParseError.new("unexpceted token", lex)
          end
        else
          a
        end
      }
      t
    end
    #
    #11.13
    #
    def assignment_exp(lex, context, options)
      @logger.debug "*** assignment_exp"

      left_hand = nil
      t = cond_exp(lex, context, options)
      return nil if t.nil?
      lex.eval_lit {
        left_hand = t
        punc = lex.next_lit
        if punc == ECMA262::PUNC_LET ||
           punc == ECMA262::PUNC_DIVLET ||
           punc == ECMA262::PUNC_MULLET ||
           punc == ECMA262::PUNC_MODLET ||
           punc == ECMA262::PUNC_ADDLET ||
           punc == ECMA262::PUNC_SUBLET ||
           punc == ECMA262::PUNC_LSHIFTLET ||
           punc == ECMA262::PUNC_RSHIFTLET ||
           punc == ECMA262::PUNC_URSHIFTLET ||
           punc == ECMA262::PUNC_ANDLET ||
           punc == ECMA262::PUNC_ORLET ||
           punc == ECMA262::PUNC_XORLET
          lex.fwd_lit(nil)
          if b = assignment_exp(lex, context, options)
            case punc
            when ECMA262::PUNC_LET
              ECMA262::ExpAssign.new(left_hand, b)
            when ECMA262::PUNC_DIVLET
              ECMA262::ExpDivAssign.new(left_hand, b)
            when ECMA262::PUNC_MULLET
              ECMA262::ExpMulAssign.new(left_hand, b)
            when ECMA262::PUNC_MODLET
              ECMA262::ExpModAssign.new(left_hand, b)
            when ECMA262::PUNC_ADDLET
              ECMA262::ExpAddAssign.new(left_hand, b)
            when ECMA262::PUNC_SUBLET
              ECMA262::ExpSubAssign.new(left_hand, b)
            when ECMA262::PUNC_LSHIFTLET
              ECMA262::ExpLShiftAssign.new(left_hand, b)
            when ECMA262::PUNC_RSHIFTLET
              ECMA262::ExpRShiftAssign.new(left_hand, b)
            when ECMA262::PUNC_URSHIFTLET
              ECMA262::ExpURShiftAssign.new(left_hand, b)
            when ECMA262::PUNC_ANDLET
              ECMA262::ExpAndAssign.new(left_hand, b)
            when ECMA262::PUNC_ORLET
              ECMA262::ExpOrAssign.new(left_hand, b)
            when ECMA262::PUNC_XORLET
              ECMA262::ExpXorAssign.new(left_hand, b)
            else
              raise "internal error"
            end
          else
            raise ParseError.new("unexpceted token", lex)
          end
        else
          @logger.debug {
            "*** assignment_exp => #{t ? t.to_js : t}"
          }
          t
        end
      }
    end

    #
    # 11.14
    #
    def exp(lex, context, options)
      @logger.debug "*** expression"
      lex.eval_lit{
        t = assignment_exp(lex, context, {:hint => :regexp}.merge(options))
        while punc = lex.eql_lit?(ECMA262::PUNC_COMMA)
          if b = assignment_exp(lex,context, {:hint => :regexp}.merge(options))
            t = ECMA262::ExpComma.new(t, b)
          else
            raise ParseError.new("unexpceted token", lex)
          end
        end
        @logger.debug{
          "*** expression => #{t ? t.to_js : t}"
        }
        t
      }
    end
  end
end
