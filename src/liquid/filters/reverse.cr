require "./array_helpers"

module Liquid::Filters
  # reverse
  #
  # Reverses the order of the items in an array, nested arrays are flattened. Any other value is treated as a single
  # element array.
  class Reverse
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      ArrayHelpers.check_args("reverse", args, 0..0)

      Any.new(ArrayHelpers.to_array(data).reverse)
    end
  end

  FilterRegister.register "reverse", Reverse
end
