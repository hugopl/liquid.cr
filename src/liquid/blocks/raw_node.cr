require "./block"

module Liquid::Block
  class RawNode < Node
    extend Block

    property content

    @content : String

    # True if this node holds the contents of a `{% raw %}` tag, false if it's just text between tags.
    getter? raw_tag : Bool

    def initialize(@content, @raw_tag = false)
    end

    def blank? : Bool
      @raw_tag ? @content.empty? : @content.each_char.all?(&.whitespace?)
    end

    def lstrip!
      @content = @content.lstrip
    end

    def rstrip!
      @content = @content.rstrip
    end

    def inspect(io : IO)
      inspect(io) { io << @content.inspect }
    end

    def_equals @children, @content
  end
end
