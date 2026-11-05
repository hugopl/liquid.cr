require "./block"

module Liquid::Block
  # Renders its block only if the output is different from the last time an ifchanged block was rendered.
  class IfChanged < BeginBlock
    def initialize(content : String)
    end
  end
end
