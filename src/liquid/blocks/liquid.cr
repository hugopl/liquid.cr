require "./block"

module Liquid::Block
  # Container for the tags written inside a `{% liquid %}` tag.
  #
  # The children are rendered as if they were written outside the liquid tag, this node only exists to keep the
  # whitespace control information of the `{% liquid %}` tag.
  class LiquidTag < Node
    extend Block

    def initialize
    end

    def initialize(content : String)
    end
  end
end
