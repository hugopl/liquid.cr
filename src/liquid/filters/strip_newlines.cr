require "./base"
require "./string_helpers"

module Liquid::Filters
  #   strip_newlines
  #
  # Removes any newline characters (line breaks) from a string.
  #
  # Input
  # {% capture string_with_newlines %}
  # Hello
  # there
  # {% endcapture %}
  #
  # {{ string_with_newlines | strip_newlines }}
  #
  # Output
  # Hellothere
  class StripNewLines
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("strip_newlines", args, 0)

      Any.new(data.to_s.gsub(/\r?\n/, ""))
    end
  end

  FilterRegister.register "strip_newlines", StripNewLines
end
