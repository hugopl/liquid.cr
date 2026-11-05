require "html"
require "./base"
require "./string_helpers"

module Liquid::Filters
  #   escape
  #
  # Escapes a string by replacing characters with escape sequences (so that the string can be used in a URL, for example). It doesn’t change strings that don’t have anything to escape.
  #
  # Input
  # {{ "1 < 2 & 3" | escape_once }}
  #
  # Output
  # 1 &lt; 2 &amp; 3
  #
  # Input
  # {{ "1 &lt; 2 &amp; 3" | escape_once }}
  #
  # Output
  # 1 &lt; 2 &amp; 3
  class EscapeOnce
    extend Filter

    # From crystal/src/html.cr
    private SUBSTITUTIONS = {
      '&'  => "&amp;",
      '<'  => "&lt;",
      '>'  => "&gt;",
      '"'  => "&quot;",
      '\'' => "&#39;",
    }

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("escape_once", args, 0)

      str = data.to_s
      SUBSTITUTIONS.each do |key, val|
        str = str.gsub(key, val) if key != '&'
      end
      str = str.gsub(/&(?!(?:[a-z][a-z\d]*|#(?:\d+|[xX][a-f\d]+));)/, "&amp;")

      Any.new(str)
    end
  end

  FilterRegister.register "escape_once", EscapeOnce
end
