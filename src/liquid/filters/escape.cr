require "html"

require "./base"
require "./string_helpers"

module Liquid::Filters
  #   escape
  #
  # Escapes a string by replacing characters with escape sequences (so that the string can be used in a URL, for example). It doesn’t change strings that don’t have anything to escape.
  #
  # Input
  # {{ "Have you read 'James & the Giant Peach'?" | escape }}
  #
  # Output
  # Have you read &#39;James &amp; the Giant Peach&#39;?
  #
  # Input
  # {{ "Tetsuro Takara" | escape }}
  #
  # Output
  # Tetsuro Takara
  class Escape
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("escape", args, 0)
      return data if data.raw.nil?

      Any.new(HTML.escape(data.to_s))
    end
  end

  FilterRegister.register "escape", Escape
end
