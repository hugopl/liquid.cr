require "./expression_parser"

module Liquid
  # This represent a liquid expression used in under `{{ }}` or passed to statements like if, case, etc... including
  # filter and their arguments.
  #
  # The Expression is reentrant and doesn't store any state besides the parsed expression.
  #
  # To evaluate a expression call the `eval` method with the desired `Context`.
  #
  # Raises `SyntaxError` if the expression is invalid.
  struct Expression
    getter expression : String
    getter term : Term

    def initialize(@expression : String)
      @term = ExpressionParser.parse(@expression)
    end

    def_equals @expression

    def eval(ctx : Context) : Any
      @term.eval(ctx)
    end

    # Evaluates the expression, returns nil if a filter fails, the error is handled according to the context error
    # mode. Used by tags that must do nothing on errors, like `assign`.
    def eval?(ctx : Context) : Any?
      term = @term
      term.is_a?(Filtered) ? term.eval_filters(ctx) : term.eval(ctx)
    rescue e : Liquid::FilterArgumentException
      ctx.add_error(e)
      nil
    end

    # Returns true if this expression matches *value*, as in a `when` clause of a `case` tag. This handle the special
    # `blank` and `empty` literals.
    def matches?(ctx : Context, value : Any) : Bool
      @term.matches?(ctx, value)
    end

    def to_s(io : IO)
      io << @expression
    end
  end
end
