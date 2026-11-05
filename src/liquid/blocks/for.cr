require "./block"
require "./else"
require "../context"
require "../expression"

module Liquid::Block
  # Collection expression used by `for` and `tablerow` tags, it can be a range literal like `(1..foo)` or any
  # other expression.
  struct LoopCollection
    private RANGE = /\A\(?\s*(.+?)\s*\.\.\s*(.+?)\s*\)?\z/

    getter markup : String
    @range : Tuple(Expression, Expression)?
    @expression : Expression?

    def initialize(@markup : String)
      if (@markup.starts_with?('(') && @markup.ends_with?(')')) || @markup.matches?(/\A[^'"]+\.\.[^'"]+\z/)
        match = @markup.match(RANGE)
        raise SyntaxError.new("Invalid range expression: #{@markup}.") if match.nil?

        @range = {Expression.new(match[1]), Expression.new(match[2])}
      else
        @expression = Expression.new(@markup)
      end
    end

    # Evaluates the collection, returning nil if it's undefined/nil.
    def eval(ctx : Context) : Array(Any)?
      if range = @range
        first = range_bound(range[0].eval(ctx))
        last = range_bound(range[1].eval(ctx))
        return (first..last).map { |i| Any.new(i) }
      end

      value = @expression.not_nil!.eval(ctx)
      raw = value.raw
      case raw
      when Nil
        nil
      when Array
        raw
      when Hash
        raw.map { |key, val| Any{key, val} }
      when String
        raw.empty? ? [] of Any : [value]
      when Range
        raw.to_a.map { |i| Any.new(i) }
      else
        [] of Any
      end
    end

    private def range_bound(value : Any) : Int32
      raw = value.raw
      case raw
      when Int    then raw.to_i
      when Float  then raw.to_i
      when String then raw.to_i?(strict: false) || 0
      else             0
      end
    end
  end

  # Parsed markup of `for` and `tablerow` tags: `var in collection [reversed] [attr: value[,] ...]`.
  struct LoopMarkup
    private SYNTAX    = /\A\s*([\w-]+\??)\s+in\s+/
    private FRAGMENT  = /\A(?:[^\s,|'"]|"[^"]*"|'[^']*')+/
    private REVERSED  = /\A\s*reversed\b/
    private ATTRIBUTE = /([\w-]+)\s*:\s*("[^"]*"|'[^']*'|[^\s,]+)/

    getter markup : String
    getter loop_var : String
    getter collection : LoopCollection
    getter? reversed = false
    getter attributes = Hash(String, String).new

    def initialize(@markup : String, tag_name : String)
      match = markup.match(SYNTAX)
      raise SyntaxError.new("Invalid #{tag_name} node: #{markup}.") if match.nil?

      @loop_var = match[1]
      rest = markup[match.end..]
      collection_markup = if rest.starts_with?('(')
                            close = rest.index(')')
                            raise SyntaxError.new("Invalid #{tag_name} node: #{markup}.") if close.nil?
                            rest[0..close]
                          else
                            rest[FRAGMENT]? || raise SyntaxError.new("Invalid #{tag_name} node: #{markup}.")
                          end
      @collection = LoopCollection.new(collection_markup)
      rest = rest[collection_markup.size..]
      if reversed = rest.match(REVERSED)
        @reversed = true
        rest = rest[reversed.end..]
      end
      rest.scan(ATTRIBUTE) do |attr|
        @attributes[attr[1]] = attr[2]
      end
    end

    # Name of the loop used as key for offset:continue and as forloop.name.
    def name : String
      "#{@loop_var}-#{@collection.markup}"
    end
  end

  # Inside of a for-loop block, you can access some special variables using `forloop` object, see `ForLoop`.
  class For < BeginBlock
    getter loop : LoopMarkup
    getter else : Else?
    getter limit : Expression?
    getter offset : Expression?
    getter? offset_continue = false

    def initialize(content : String)
      @loop = LoopMarkup.new(content, "for")
      @loop.attributes.each do |key, value|
        case key
        when "limit"
          @limit = Expression.new(value)
        when "offset"
          if value == "continue"
            @offset_continue = true
          else
            @offset = Expression.new(value)
          end
        end
      end
    end

    delegate markup, loop_var, collection, reversed?, to: @loop

    def <<(node : Node)
      if else_node = @else
        else_node << node
      else
        @children << node
      end
    end

    def <<(node : Else)
      raise SyntaxError.new("Multiple Else in For statement.") if @else

      @else = node
    end

    def inspect(io : IO)
      inspect(io) do
        io << markup.inspect
      end
    end

    def_equals markup, @children, @else
  end
end
