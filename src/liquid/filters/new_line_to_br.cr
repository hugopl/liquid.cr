require "./base"
require "./string_helpers"

module Liquid::Filters
  #   newline_to_br
  #
  # Replaces every newline (\n) with an HTML line break (<br>).
  #
  # Input
  # {% capture string_with_newlines %}
  # Hello
  # there
  # {% endcapture %}
  #
  # {{ string_with_newlines | newline_to_br }}
  #
  # Output
  # <br />
  # Hello<br />
  # there<br />
  class NewLineToBr
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("newline_to_br", args, 0)

      Any.new(data.to_s.gsub(/\r?\n/, "<br />\n"))
    end
  end

  FilterRegister.register "newline_to_br", NewLineToBr
end
