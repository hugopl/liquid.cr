require "./block"

module Liquid::Block
  class Capture < BeginBlock
    getter var_name : String

    def initialize(content : String)
      match = content.match(/(?:#{VARIABLE_SIGNATURE})+/)
      raise SyntaxError.new("Syntax Error in 'capture' - Valid syntax: capture [var]") if match.nil?

      @var_name = match[0]
    end

    def blank? : Bool
      true
    end
  end
end
