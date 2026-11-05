require "./base"
require "./string_helpers"

module Liquid::Filters
  #   split
  #
  # Divides an input string into an array using the argument as a separator. split is commonly used to convert comma-separated items from a string to an array.
  #
  # Input
  # {% assign beatles = "John, Paul, George, Ringo" | split: ", " %}
  #
  # {% for member in beatles %}
  #   {{ member }}
  # {% endfor %}
  #
  # Output
  #   John
  #
  #   Paul
  #
  #   George
  #
  #   Ringo
  class Split
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("split", args, 1)

      pattern = args.first.to_s
      input = data.to_s
      # Like Ruby, a single space splits on any whitespace and ignores leading whitespace.
      parts = pattern == " " ? input.split(/[ \t\n\v\f\r]+/).tap { |a| a.shift if a.first? == "" } : input.split(pattern)
      # Like Ruby, trailing empty strings are removed.
      while parts.last? == ""
        parts.pop
      end

      Any.new(parts.map { |part| Any.new(part) })
    end
  end

  FilterRegister.register "split", Split
end
