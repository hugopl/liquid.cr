require "./block"

module Liquid::Block
  # Node used for `{% comment %}`, `{% doc %}` and inline comments (`{% # ... %}`).
  #
  # The contents of a comment are never parsed nor rendered, the node only exists to keep the whitespace control
  # information of the tags.
  class Comment < Node
    extend Block

    def initialize
    end

    def initialize(content : String)
    end

    def content
      ""
    end

    def <<(node : Node)
    end

    def blank? : Bool
      true
    end

    def_equals @children, content
  end
end
