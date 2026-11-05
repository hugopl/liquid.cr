require "./any"
require "./context"
require "./exceptions"
require "./filters"

module Liquid
  struct Expression
    # Base class for nodes of a parsed expression.
    abstract class Term
      abstract def eval(ctx : Context) : Any

      # Returns true if the value of this term is equal to *value*, as in `this == value`.
      def matches?(ctx : Context, value : Any) : Bool
        eval(ctx) == value
      end

      protected def error(ctx : Context, message : String) : Any
        ctx.add_error(InvalidExpression.new(message))
      end
    end

    class Literal < Term
      getter value : Any

      def initialize(@value : Any)
      end

      def eval(ctx : Context) : Any
        @value
      end
    end

    # `blank` and `empty`, they evaluate to an empty string, but when used in a comparison they check if the other
    # operand is blank/empty.
    class MethodLiteral < Term
      enum Kind
        Blank
        Empty
      end

      getter kind : Kind

      def initialize(@kind : Kind)
      end

      def eval(ctx : Context) : Any
        Any.new("")
      end

      def matches?(ctx : Context, value : Any) : Bool
        test(value)
      end

      def test(value : Any) : Bool
        raw = value.raw
        if @kind.blank?
          case raw
          when Nil, Bool   then !raw
          when String      then raw.each_char.all?(&.whitespace?)
          when Array, Hash then raw.empty?
          else                  false
          end
        else
          case raw
          when String, Array, Hash then raw.empty?
          else                          false
          end
        end
      end
    end

    record PathItem, key : Term, dot : Bool

    # Variable lookup, like `foo`, `foo.bar`, `foo[0]` or `[foo].bar`.
    class Lookup < Term
      COMMANDS = {"size", "first", "last"}

      getter name : String | Term
      getter path : Array(PathItem)

      def initialize(@name : String | Term, @path : Array(PathItem))
      end

      def eval(ctx : Context) : Any
        obj = eval_root(ctx)
        @path.each do |item|
          key = item.key.eval(ctx)
          obj = lookup(ctx, obj, key, item.dot)
        end
        obj
      end

      private def eval_root(ctx : Context) : Any
        name = @name
        if name.is_a?(Term)
          key = name.eval(ctx).raw
          return ctx.get(key.to_s) if key.is_a?(String) || key.is_a?(Number)

          return Any.new(nil)
        end

        value = ctx[name]?
        return value if value

        if name.ends_with?('?')
          value = ctx[name.rchop]?
          return value if value
        end
        ctx.get(name)
      end

      private def lookup(ctx : Context, obj : Any, key : Any, dot : Bool) : Any
        raw = obj.raw
        key_raw = key.raw
        case raw
        when Hash
          if key_raw.is_a?(String) && (value = raw[key_raw]?)
            return value
          end
          return Any.new(nil) unless dot && key_raw.is_a?(String)

          case key_raw
          when "size"                then Any.new(raw.size)
          when "first"               then raw.first?.try { |(k, v)| Any.new([Any.new(k), v]) } || Any.new(nil)
          when "present", "present?" then Any.new(!raw.empty?)
          when "blank", "blank?"     then Any.new(raw.empty?)
          else
            error(ctx, "Method \"#{key_raw}\" not found.")
          end
        when Array
          if key_raw.is_a?(Int)
            raw[key_raw]? || Any.new(nil)
          elsif dot
            case key_raw
            when "size"                then Any.new(raw.size)
            when "first"               then raw.first? || Any.new(nil)
            when "last"                then raw.last? || Any.new(nil)
            when "present", "present?" then Any.new(!raw.empty?)
            when "blank", "blank?"     then Any.new(raw.empty?)
            else
              error(ctx, "Tried to access property \"#{key_raw}\" of an array.")
            end
          else
            Any.new(nil)
          end
        when String
          return Any.new(nil) unless dot

          case key_raw
          when "size"                then Any.new(raw.size)
          when "first"               then Any.new(raw[0]?.to_s)
          when "last"                then Any.new(raw[-1]?.to_s)
          when "present", "present?" then Any.new(!raw.empty?)
          when "blank", "blank?"     then Any.new(raw.empty?)
          else
            error(ctx, "Tried to access property \"#{key_raw}\" of a string.")
          end
        when Drop
          begin
            raw.call(key_raw.to_s)
          rescue e : InvalidExpression
            ctx.add_error(e)
          end
        when Nil
          case key_raw
          when "blank", "blank?"     then Any.new(true)
          when "present", "present?" then Any.new(false)
          else                            Any.new(nil)
          end
        else
          return Any.new(nil) unless dot

          error(ctx, "Tried to access property \"#{key_raw}\" of a #{raw.class.name}.")
        end
      end
    end

    # A range literal like `(1..5)`, evaluated to an array of integers.
    class RangeTerm < Term
      getter range_start : Term
      getter range_end : Term

      def initialize(@range_start : Term, @range_end : Term)
      end

      def eval(ctx : Context) : Any
        first = to_integer(ctx, @range_start)
        return Any.new(nil) if first.nil?

        last = to_integer(ctx, @range_end)
        return Any.new(nil) if last.nil?

        array = Array(Any).new
        (first..last).each do |i|
          array << (i.in?(Int32::MIN..Int32::MAX) ? Any.new(i.to_i32) : Any.new(i))
        end
        Any.new(array)
      end

      private def to_integer(ctx : Context, term : Term) : Int64?
        value = term.eval(ctx).raw
        case value
        when Int
          value.to_i64
        when Float
          # Float literals are truncated, but floats from variables are an error, like in Shopify liquid.
          return value.to_i64 if term.is_a?(Literal)

          error(ctx, "invalid integer")
          nil
        when Nil
          0_i64
        when String
          value.strip.match(/\A[+-]?\d+/).try(&.[0].to_i64?) || 0_i64
        else
          error(ctx, "invalid integer")
          nil
        end
      end
    end

    class Comparison < Term
      getter operator : String
      getter left : Term
      getter right : Term

      def initialize(@operator : String, @left : Term, @right : Term)
      end

      def eval(ctx : Context) : Any
        left = @left
        right = @right
        case @operator
        when "=="       then Any.new(equals?(ctx, left, right))
        when "!=", "<>" then Any.new(!equals?(ctx, left, right))
        when "contains" then Any.new(contains?(ctx, left, right))
        else
          return Any.new(nil) if left.is_a?(MethodLiteral) || right.is_a?(MethodLiteral)

          compare(ctx, left.eval(ctx), right.eval(ctx))
        end
      end

      private def equals?(ctx : Context, left : Term, right : Term) : Bool
        if left.is_a?(MethodLiteral)
          return false if right.is_a?(MethodLiteral)

          left.test(right.eval(ctx))
        elsif right.is_a?(MethodLiteral)
          right.test(left.eval(ctx))
        else
          left.eval(ctx) == right.eval(ctx)
        end
      end

      private def contains?(ctx : Context, left : Term, right : Term) : Bool
        return false if left.is_a?(MethodLiteral)

        left_raw = left.eval(ctx).raw
        right_value = right.eval(ctx)
        right_raw = right_value.raw
        return false if right_raw.nil? || right_raw == false

        case left_raw
        when String
          return true if right.is_a?(MethodLiteral)

          left_raw.includes?(right_raw.to_s)
        when Array
          return false if right.is_a?(MethodLiteral)

          left_raw.includes?(right_value)
        when Hash
          right_raw.is_a?(String) && !right.is_a?(MethodLiteral) && left_raw.has_key?(right_raw)
        else
          false
        end
      end

      private def compare(ctx : Context, left : Any, right : Any) : Any
        l = left.raw
        r = right.raw
        if l.is_a?(Number) && r.is_a?(Number)
          Any.new(compare_values(l, r))
        elsif l.is_a?(String) && r.is_a?(String)
          Any.new(compare_values(l, r))
        elsif l.is_a?(Time) && r.is_a?(Time)
          Any.new(compare_values(l, r))
        elsif comparable?(l) && comparable?(r)
          error(ctx, "comparison of #{type_name(l)} with #{type_name(r)} failed")
        else
          Any.new(nil)
        end
      end

      private def compare_values(l, r) : Bool
        case @operator
        when "<"  then l < r
        when "<=" then l <= r
        when ">"  then l > r
        when ">=" then l >= r
        else           false
        end
      end

      private def comparable?(value) : Bool
        value.is_a?(Number) || value.is_a?(String) || value.is_a?(Time)
      end

      private def type_name(value) : String
        case value
        when Int    then "Integer"
        when Float  then "Float"
        when String then "String"
        else             value.class.name
        end
      end
    end

    class And < Term
      getter left : Term
      getter right : Term

      def initialize(@left : Term, @right : Term)
      end

      def eval(ctx : Context) : Any
        Any.new(!!(@left.eval(ctx).raw && @right.eval(ctx).raw))
      end
    end

    class Or < Term
      getter left : Term
      getter right : Term

      def initialize(@left : Term, @right : Term)
      end

      def eval(ctx : Context) : Any
        Any.new(!!(@left.eval(ctx).raw || @right.eval(ctx).raw))
      end
    end

    record FilterCall, name : String, args : Array(Term), kwargs : Array({String, Term})

    class Filtered < Term
      getter input : Term
      getter filters : Array(FilterCall)

      def initialize(@input : Term, @filters : Array(FilterCall))
      end

      def eval(ctx : Context) : Any
        eval_filters(ctx)
      rescue e : Liquid::FilterArgumentException
        ctx.add_error(e)

        # Shopify liquid returns the filter error message instead of nil, so do we.
        Any.new(e.message)
      end

      # Like `eval`, but raises `FilterArgumentException` if a filter fails.
      def eval_filters(ctx : Context) : Any
        operand = @input.eval(ctx)
        @filters.each do |call|
          filter = Filters::FilterRegister.get(call.name)
          return ctx.add_error(UndefinedFilter.new(call.name)) if filter.nil?

          args = call.args.map(&.eval(ctx))
          kwargs = call.kwargs.map { |(name, term)| {name, term.eval(ctx)} }

          ctx.reset_filter_context
          filter_args = ctx.filter_args
          filter_options = ctx.filter_options
          filter_args.concat(args)
          kwargs.each { |(name, value)| filter_options[name] = value }
          operand = filter.filter(operand, filter_args, filter_options)
        end
        operand
      end
    end
  end
end
