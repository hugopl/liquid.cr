require "./array_helpers"

module Liquid::Filters
  # sort_natural
  #
  # Sorts the items in an array in case-insensitive order, optionally by a property of the items. Items are compared
  # as strings.
  #
  # Input
  # {% assign my_array = "zebra, octopus, giraffe, Sally Snake" | split: ", " %}
  # {{ my_array | sort_natural | join: ", " }}
  #
  # Output
  # giraffe, octopus, Sally Snake, zebra
  class SortNatural
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      ArrayHelpers.check_args("sort_natural", args, 0..1)
      ArrayHelpers.sort(data, args.first?) { |a, b| compare(a, b) }
    end

    # Case insensitive comparison of two values as strings, `nil` values go to the end.
    def self.compare(a : Any, b : Any) : Int32
      a_nil = a.raw.nil?
      b_nil = b.raw.nil?
      if !a_nil && !b_nil
        a.to_s.compare(b.to_s, case_insensitive: true)
      elsif a_nil && b_nil
        0
      else
        a_nil ? 1 : -1
      end
    end
  end

  FilterRegister.register "sort_natural", SortNatural
end
