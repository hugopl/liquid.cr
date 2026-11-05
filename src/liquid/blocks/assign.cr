require "./block"
require "../regex"
require "../block_register"

module Liquid::Block
  class Assign < InlineBlock
    ASSIGN = /\A(?<varname>(?:#{VARIABLE_SIGNATURE})+)\s*=\s*(?<value>.*)\z/m

    @varname : String
    @value : Expression

    getter varname, value

    def initialize(@varname, @value)
    end

    def initialize(content : String)
      if match = content.strip.match ASSIGN
        @varname = match["varname"]
        @value = Expression.new match["value"]
      else
        raise SyntaxError.new("Invalid assignment Node")
      end
    end

    def blank? : Bool
      true
    end

    def_equals @varname, @value
  end
end
