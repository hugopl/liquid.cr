require "./base"
require "./string_helpers"

module Liquid::Filters
  # truncate
  #
  # Shortens a string down to the number of characters passed as an argument (50 by default). If the specified number
  # of characters is less than the length of the string, an ellipsis (...) is appended to the string and is included
  # in the character count. A custom ellipsis can be given as second argument.
  #
  # Input
  # {{ "Ground control to Major Tom." | truncate: 20 }}
  # {{ "Ground control to Major Tom." | truncate: 25, ", and so on" }}
  #
  # Output
  # Ground control to...
  # Ground control, and so on
  class Truncate
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("truncate", args, 0, 2)
      return data if data.raw.nil?

      input = data.to_s
      length = args.empty? ? 50 : StringHelpers.to_integer("truncate", args[0])
      ellipsis = args.size > 1 ? args[1].to_s : "..."
      return Any.new(input) if input.size <= length

      Any.new(input[0, Math.max(length - ellipsis.size, 0)] + ellipsis)
    end
  end

  FilterRegister.register "truncate", Truncate
end
