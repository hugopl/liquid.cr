require "./array_helpers"

module Liquid::Filters
  # find_index
  #
  # Returns the index of the first item in an array with a specific property value, if no value is given returns the
  # index of the first item with a truthy property.
  #
  # Input
  # {{ products | find_index: "type", "kitchen" }}
  class FindIndex
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      ArrayHelpers.filter_array("find_index", data, args, Any.new) do |items, matcher|
        Any.new(items.index { |i| matcher.call(i) })
      end
    end
  end

  FilterRegister.register "find_index", FindIndex
end
