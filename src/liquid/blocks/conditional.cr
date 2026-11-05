require "./block"
require "./else"
require "./elsif"
require "../expression"

module Liquid::Block
  # Base class for if/unless tags
  abstract class Conditional < BeginBlock
    enum PutInto
      Conditional
      Elsif
      Else
      # Blocks after the first `else` are never rendered, like in Shopify liquid.
      Nothing
    end

    getter expression : Expression
    getter elsif : Array(ElsIf)?
    getter else : Else?

    @put_into = PutInto::Conditional

    def initialize(@expression)
    end

    def initialize(content : String)
      @expression = Expression.new(content)
    end

    def <<(node : Node)
      case @put_into
      when PutInto::Conditional
        @children << node
      when PutInto::Elsif
        @elsif.not_nil!.last << node
      when PutInto::Else
        @else.not_nil! << node
      when PutInto::Nothing
      end
    end

    def <<(node : ElsIf)
      if @else
        @put_into = PutInto::Nothing
        return
      end

      elsif_arr = @elsif ||= Array(ElsIf).new
      elsif_arr << node
      @put_into = PutInto::Elsif
    end

    def <<(node : Else)
      if @else
        @put_into = PutInto::Nothing
        return
      end

      @else = node
      @put_into = PutInto::Else
    end

    # All branches of this conditional.
    def bodies : Array(Node)
      bodies = [self] of Node
      @elsif.try { |arr| bodies.concat(arr) }
      @else.try { |node| bodies << node }
      bodies
    end

    def blank? : Bool
      bodies.all? { |body| body.children.all?(&.blank?) }
    end

    def remove_blank_strings : Nil
      bodies.each(&.remove_blank_strings_from_children)
    end

    def inspect(io : IO)
      inspect(io) do
        io << @expression.expression.inspect
      end
    end

    def_equals @expression, @elsif, @else, @children
  end
end
