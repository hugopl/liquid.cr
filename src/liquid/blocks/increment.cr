require "../blocks"

module Liquid::Block
  class Increment < Liquid::Block::InlineBlock
    getter var_name : String

    def initialize(content @var_name)
      raise SyntaxError.new("Invalid variable name: #{@var_name}.") unless @var_name.matches?(/\A[\w-]+\??\z/)
    end
  end
end
