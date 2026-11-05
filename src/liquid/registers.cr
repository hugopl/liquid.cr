require "./any"
require "./for_loop"

module Liquid
  # :nodoc:
  # Raised by `{% break %}` and caught by the enclosing loop.
  class BreakInterrupt < Exception
  end

  # :nodoc:
  # Raised by `{% continue %}` and caught by the enclosing loop.
  class ContinueInterrupt < Exception
  end

  # Render state shared by all templates rendered with the same `Context` (e.g. by `include` tags), like
  # `increment`/`decrement` counters, `cycle` positions, `for` offsets used by `offset: continue`, etc.
  class Registers
    # Counters used by `increment` and `decrement` tags, kept apart from variables set by `assign`.
    getter counters = Hash(String, Int32).new
    # Iteration of each `cycle` tag, by cycle key.
    getter cycles = Hash(Any, Int32).new
    # Offset where a `for` loop stopped, by loop name, used by `offset: continue`.
    getter for_offsets = Hash(String, Int32).new
    # Stack of active `for` loops, used to fill `forloop.parentloop`.
    getter for_stack = Array(ForLoop).new
    # Number of loops (`for` and `tablerow`) being rendered, used to propagate `break` and `continue` from includes.
    property loop_depth = 0
    # Last output of an `ifchanged` tag.
    property ifchanged : String?
  end
end
