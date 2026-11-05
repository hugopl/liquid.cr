require "./block"
require "./else"
require "../expression"
require "./when"

module Liquid::Block
  class Case < BeginBlock
    getter expression : Expression
    # `when` and `else` blocks in the order they appear, Shopify liquid allows multiple `else` blocks and `when`
    # blocks after an `else`.
    getter blocks = Array(When | Else).new

    def initialize(@expression)
    end

    def initialize(content : String)
      @expression = Expression.new(content)
    end

    def <<(node : Node)
      # Nodes before the first `when` (probably white space) are ignored.
      @blocks.last?.try(&.<<(node))
    end

    def <<(node : When)
      @blocks << node
    end

    def <<(node : Else)
      @blocks << node
    end

    def when : Array(When)?
      whens = @blocks.compact_map(&.as?(When))
      whens unless whens.empty?
    end

    def else : Else?
      @blocks.each { |block| return block if block.is_a?(Else) }
      nil
    end

    def blank? : Bool
      @blocks.all? { |block| block.children.all?(&.blank?) }
    end

    def remove_blank_strings : Nil
      @blocks.each(&.remove_blank_strings_from_children)
    end

    def inspect(io : IO)
      inspect(io) { io << @expression.expression.inspect }
    end

    def_equals @blocks, @children
  end
end
