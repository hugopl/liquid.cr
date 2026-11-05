require "./base"
require "./string_helpers"

module Liquid::Filters
  # truncatewords
  #
  # Shortens a string down to the number of words passed as an argument (15 by default). If the specified number of
  # words is less than the number of words in the string, an ellipsis (...) is appended to the string. A custom
  # ellipsis can be given as second argument.
  #
  # Input
  # {{ "Ground control to Major Tom." | truncatewords: 3 }}
  # {{ "Ground control to Major Tom." | truncatewords: 3, "--" }}
  #
  # Output
  # Ground control to...
  # Ground control to--
  class TruncateWords
    extend Filter

    private WORD = /[^ \t\n\v\f\r]+/

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("truncatewords", args, 0, 2)
      return data if data.raw.nil?

      input = data.to_s
      max_words = args.empty? ? 15 : StringHelpers.to_integer("truncatewords", args[0])
      max_words = 1 if max_words <= 0

      words = [] of String
      last_word_end = 0
      input.scan(WORD) do |match|
        break if words.size == max_words

        words << match[0]
        last_word_end = match.end
      end
      # Like Ruby's `input.split(" ", max_words + 1)`, the input is truncated if anything follows the last word.
      return Any.new(input) if words.size < max_words || last_word_end >= input.size

      ellipsis = args.size > 1 ? args[1].to_s : "..."
      Any.new(words.join(' ') + ellipsis)
    end
  end

  FilterRegister.register "truncatewords", TruncateWords
end
