require "./block"
require "./for"

module Liquid::Block
  # Generates an HTML table, inside the block a `tablerowloop` object is available, see `TablerowLoop`.
  #
  # Accepts `cols`, `limit` and `offset` attributes.
  class Tablerow < BeginBlock
    getter loop : LoopMarkup
    getter cols : Expression?
    getter limit : Expression?
    getter offset : Expression?

    def initialize(content : String)
      @loop = LoopMarkup.new(content, "tablerow")
      @loop.attributes.each do |key, value|
        case key
        when "cols"   then @cols = Expression.new(value)
        when "limit"  then @limit = Expression.new(value)
        when "offset" then @offset = Expression.new(value)
        end
      end
    end

    delegate markup, loop_var, collection, to: @loop

    def inspect(io : IO)
      inspect(io) do
        io << markup.inspect
      end
    end

    def_equals markup, @children
  end
end
