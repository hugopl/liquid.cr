require "./array_helpers"

module Liquid::Filters
  # has
  #
  # Tests if any item in an array has a specific property value, if no value is given tests if any item has a
  # truthy property.
  #
  # Input
  # {{ products | has: "type", "kitchen" }}
  class Has
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      ArrayHelpers.filter_array("has", data, args, Any.new(false)) do |items, matcher|
        Any.new(items.any? { |i| matcher.call(i) })
      end
    end
  end

  FilterRegister.register "has", Has
end
