require "./block"
require "../regex"
require "../expression"

module Liquid::Block
  # Base class for tags that render partial templates, i.e. `include` and `render`.
  abstract class PartialBlock < InlineBlock
    QUOTED_FRAGMENT = /"[^"]*"|'[^']*'|(?:[^\s,\|'"]|"[^"]*"|'[^']*')+/
    TAG_ATTRIBUTES  = /(?<key>\w[\w-]*)\s*:\s*(?<value>#{QUOTED_FRAGMENT})/
    PARTIAL_SYNTAX  = /\A\s*(?<name>#{QUOTED_FRAGMENT})(?:\s*,)?(?:\s+(?<keyword>with|for)\s+(?<variable>#{QUOTED_FRAGMENT}))?(?:\s+as\s+(?<alias>[\w-]+))?/

    # The tag markup, i.e. everything after the tag name.
    getter markup : String
    # Expression that evaluates to the partial template name.
    getter template_name : Expression
    # Expression given after `with` or `for` keywords.
    getter variable : Expression?
    # Variable name given after the `as` keyword.
    getter alias_name : String?
    # Variables given as keyword arguments.
    getter attributes : Hash(String, Expression)
    # True if the `for` keyword was used instead of `with`.
    getter? for_loop : Bool

    def initialize(content : String)
      @markup = content
      @attributes = Hash(String, Expression).new
      @for_loop = false
      match = content.match(PARTIAL_SYNTAX)
      raise SyntaxError.new("Invalid partial tag: #{content.inspect}.") if match.nil?

      @template_name = Expression.new(match["name"])
      if variable = match["variable"]?
        @variable = Expression.new(variable)
        @for_loop = match["keyword"] == "for"
      end
      @alias_name = match["alias"]?

      match.post_match.scan(TAG_ATTRIBUTES) do |attr|
        @attributes[attr["key"]] = Expression.new(attr["value"])
      end
      validate_template_name(match["name"])
    end

    protected def validate_template_name(name : String) : Nil
    end

    # Returns the partial template name.
    def template_name(ctx : Context) : String
      @template_name.eval(ctx).to_s
    end

    def inspect(io : IO)
      inspect(io) { io << @markup.inspect }
    end

    def_equals @markup
  end

  # The include tag renders a partial template using the same context of the parent template.
  class Include < PartialBlock
  end

  # The render tag renders a partial template using an isolated context.
  class Render < PartialBlock
    protected def validate_template_name(name : String) : Nil
      return if name =~ /\A#{STRING}\z/

      raise SyntaxError.new("Template name for render tag must be a quoted string, got #{name}.")
    end
  end
end
