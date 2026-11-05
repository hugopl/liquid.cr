require "./block"
require "../tokenizer"

module Liquid::Block
  class When < InlineBlock
    private LAX_WHEN_SYNTAX = /(#{Tokenizer::QuotedFragment})(?:(?:\s+or\s+|\s*\,\s*)(#{Tokenizer::QuotedFragment}.*))?/m

    getter markup : String
    getter when_expressions : Array(Expression)
    # Syntax error found when parsing the markup strictly, in this case the markup was parsed in lax mode, and this
    # error is raised at render time if the context is in strict mode.
    getter strict_error : SyntaxError?

    def initialize(content : String)
      @markup = content
      raise SyntaxError.new("No expression for When tag") if @markup.blank?

      @when_expressions = begin
        ExpressionParser.split_list(@markup).map { |expr| Expression.new(expr) }
      rescue e : SyntaxError
        @strict_error = e
        lax_parse(@markup)
      end
    end

    private def lax_parse(markup : String) : Array(Expression)
      expressions = [] of Expression
      remaining = markup
      while remaining
        match = remaining.match(LAX_WHEN_SYNTAX)
        raise SyntaxError.new("Syntax Error in tag 'case' - Valid when condition: {% when [condition] [or condition2...] %}") if match.nil?

        expressions << Expression.new(match[1])
        remaining = match[2]?
      end
      expressions
    end

    # Return the number of matches in when clause
    def match?(ctx : Context, value : Any) : Int32
      if (error = @strict_error) && ctx.strict?
        raise error
      end

      @when_expressions.count do |expr|
        expr.matches?(ctx, value)
      end
    end

    def inspect(io : IO)
      inspect(io) { io << @when_expressions.map(&.inspect).join(", ") }
    end
  end
end
