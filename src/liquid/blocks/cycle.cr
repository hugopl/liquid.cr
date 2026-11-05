require "./block"
require "../expression"
require "../context"

module Liquid::Block
  # Cycles through a list of values, outputting one at a time each time the tag is rendered.
  #
  # `{% cycle 'a', 'b' %}` or `{% cycle name: 'a', 'b' %}`.
  class Cycle < InlineBlock
    private FRAGMENT = /"[^"]*"|'[^']*'|(?:[^\s,|'"]|"[^"]*"|'[^']*')+/
    private NAMED    = /\A\s*(#{FRAGMENT})\s*:\s*(.*)\z/m
    private SIMPLE   = /\A\s*#{FRAGMENT}/
    private LITERAL  = /\A(?:"[^"]*"|'[^']*'|-?\d+(?:\.\d+)?|true|false|nil|null)\z/

    getter markup : String
    # Name of a named cycle, evaluated at render time to get the cycle key.
    getter name : Expression?
    getter values : Array(Expression)
    # Key used for unnamed cycles.
    getter key : String

    def initialize(content : String)
      @markup = content
      if match = content.match(NAMED)
        @name = Expression.new(match[1])
        @values = parse_values(match[2])
        @key = ""
      elsif content.matches?(SIMPLE)
        @values = parse_values(content)
        # Like Shopify liquid, unnamed cycles with the same literal values share the same counter, but if there's
        # any variable lookup they don't.
        @key = if @values.all?(&.expression.matches?(LITERAL))
                 literal_ctx = Context.new
                 @values.map(&.eval(literal_ctx).inspect).join(", ")
               else
                 "cycle-#{object_id}"
               end
      else
        raise SyntaxError.new("Syntax Error in 'cycle' - Valid syntax: cycle [name :] var [, var2, var3 ...]")
      end
    end

    private def parse_values(markup : String) : Array(Expression)
      markup.split(',').compact_map do |value|
        value = value[FRAGMENT]?
        Expression.new(value) if value
      end
    end

    def_equals @markup
  end
end
