require "./base"
require "./string_helpers"
require "./replace_last"

module Liquid::Filters
  # remove_last
  #
  # Removes only the last occurrence of the specified substring from a string.
  #
  # Input
  # {{ "I strained to see the train through the rain" | remove_last: "rain" }}
  #
  # Output
  # I strained to see the train through the
  class RemoveLast
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("remove_last", args, 1)

      Any.new(ReplaceLast.replace_last(data.to_s, args.first.to_s, ""))
    end
  end

  FilterRegister.register "remove_last", RemoveLast
end
