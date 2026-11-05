require "./base"
require "./string_helpers"

module Liquid::Filters
  # replace_last
  #
  # Replaces only the last occurrence of the first argument in a string with the second argument.
  #
  # Input
  # {{ "Take my protein pills and put my helmet on" | replace_last: "my", "your" }}
  #
  # Output
  # Take my protein pills and put your helmet on
  class ReplaceLast
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("replace_last", args, 2)

      Any.new(replace_last(data.to_s, args[0].to_s, args[1].to_s))
    end

    # :nodoc:
    def self.replace_last(input : String, search : String, replacement : String) : String
      index = input.rindex(search)
      return input if index.nil?

      String.build do |str|
        str << input[0, index] << replacement << input[(index + search.size)..]
      end
    end
  end

  FilterRegister.register "replace_last", ReplaceLast
end
