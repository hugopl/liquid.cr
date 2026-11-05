require "./array_helpers"

module Liquid::Filters
  # concat
  #
  # Concatenates (joins together) multiple arrays. The resulting array contains all the items from the input arrays.
  #
  # Input
  # {% assign fruits = "apples, oranges" | split: ", " %}
  # {% assign vegetables = "carrots, turnips" | split: ", " %}
  # {{ fruits | concat: vegetables | join: ", " }}
  #
  # Output
  # apples, oranges, carrots, turnips
  class Concat
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      ArrayHelpers.check_args("concat", args, 1..1)
      other = args.first.as_a?
      raise FilterArgumentException.new("concat filter requires an array argument") if other.nil?

      Any.new(ArrayHelpers.to_array(data) + other)
    end
  end

  FilterRegister.register "concat", Concat
end
