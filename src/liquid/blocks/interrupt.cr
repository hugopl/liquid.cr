require "./block"

module Liquid::Block
  # `{% break %}` tag.
  class Break < InlineBlock
    def initialize(content : String)
    end
  end

  # `{% continue %}` tag.
  class Continue < InlineBlock
    def initialize(content : String)
    end
  end
end
