require "./base"
require "./string_helpers"

module Liquid::Filters
  class StrSlice
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("slice", args, 1, 2)

      offset = StringHelpers.to_integer("slice", args[0])
      length_arg = args[1]?
      length = length_arg && length_arg.raw ? StringHelpers.to_integer("slice", length_arg) : 1

      array = data.as_a?
      # Ranges are sliced by their string representation, like in Shopify Liquid.
      if array && !array.is_a?(RangeArray)
        range = StringHelpers.ruby_slice_range(array.size, offset, length)
        Any.new(range ? array[range] : Array(Any).new)
      else
        str = data.to_s
        range = StringHelpers.ruby_slice_range(str.size, offset, length)
        Any.new(range ? str[range] : "")
      end
    end
  end

  FilterRegister.register "slice", StrSlice
end
