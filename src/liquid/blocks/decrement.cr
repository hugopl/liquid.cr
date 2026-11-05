require "../blocks"

module Liquid::Block
  class Decrement < Liquid::Block::InlineBlock
    getter var_name : String

    def initialize(content @var_name)
      raise SyntaxError.new("Invalid variable name: #{@var_name}.") unless @var_name.matches?(/\A[\w-]+\??\z/)
    end
  end
end
