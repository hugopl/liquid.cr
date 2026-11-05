require "../visitor"

module Liquid::Block
  abstract class Node
    getter children = Array(Node).new
    property? rstrip = false
    property? lstrip = false

    abstract def initialize(content : String)

    def accept(visitor : Visitor)
      visitor.visit self
    end

    def <<(node : Node)
      @children << node
    end

    def_equals @children

    # Returns true if this node doesn't produce any output, used to remove whitespace from control flow blocks that
    # contains only whitespace and blank nodes (assign, capture, comment, etc...), like Shopify liquid does.
    def blank? : Bool
      false
    end

    # Called by the parser after the block is parsed, if `blank?` is true. Control flow blocks (if, unless, case,
    # for...) override this to remove whitespace only text from their bodies.
    def remove_blank_strings : Nil
    end

    # :nodoc:
    def remove_blank_strings_from_children : Nil
      @children.reject! { |node| node.is_a?(RawNode) && !node.raw_tag? }
    end

    def inspect(io : IO)
      inspect(io) do
      end
    end

    protected def inspect(io : IO, &)
      io << '<'
      io << '-' if lstrip?
      io << ' '
      io << self.class.name.gsub(/(\w*::)*/, "") << ' '
      yield
      io << '-' if rstrip?
      io << '>'
    end
  end

  class Root < Node
    def initialize
    end

    def initialize(content)
    end
  end

  abstract class InlineBlock < Node
    extend Block
  end

  abstract class BeginBlock < Node
    extend Block

    def blank? : Bool
      @children.all?(&.blank?)
    end
  end

  class EndBlock < Node
    extend Block

    def blank? : Bool
      true
    end

    def initialize(content)
    end

    def initialize
    end
  end
end
