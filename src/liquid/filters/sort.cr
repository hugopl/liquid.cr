require "./array_helpers"

module Liquid::Filters
  # sort
  #
  # Sorts the items in an array in case-sensitive order, optionally by a property of the items.
  #
  # Input
  # {% assign my_array = "zebra, octopus, giraffe, Sally Snake" | split: ", " %}
  # {{ my_array | sort | join: ", " }}
  #
  # Output
  # Sally Snake, giraffe, octopus, zebra
  class Sort
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      ArrayHelpers.check_args("sort", args, 0..1)
      ArrayHelpers.sort(data, args.first?) { |a, b| compare(a, b) }
    end

    # Compare two values, `nil` values go to the end.
    def self.compare(a : Any, b : Any) : Int32
      a_raw = a.raw
      b_raw = b.raw
      if a_raw.is_a?(Number) && b_raw.is_a?(Number)
        (a_raw <=> b_raw) || 0
      elsif a_raw.is_a?(String) && b_raw.is_a?(String)
        a_raw <=> b_raw
      elsif a_raw.is_a?(Time) && b_raw.is_a?(Time)
        a_raw <=> b_raw
      elsif a_raw == b_raw
        0
      elsif a_raw.nil?
        1
      elsif b_raw.nil?
        -1
      else
        raise FilterArgumentException.new("cannot sort values of incompatible types")
      end
    end
  end

  FilterRegister.register "sort", Sort
end
