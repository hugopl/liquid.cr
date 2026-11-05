require "./array_helpers"

module Liquid::Filters
  # find
  #
  # Returns the first item in an array with a specific property value, if no value is given returns the first item
  # with a truthy property.
  #
  # Input
  # {% assign product = products | find: "type", "kitchen" %}
  class Find
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      ArrayHelpers.filter_array("find", data, args, Any.new) do |items, matcher|
        items.find { |i| matcher.call(i) } || Any.new
      end
    end
  end

  FilterRegister.register "find", Find
end
