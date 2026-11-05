require "./array_helpers"

module Liquid::Filters
  # where
  #
  # Filters an array to include only items with a specific property value, if no value is given items with a
  # truthy property are selected.
  #
  # Input
  # {% assign kitchen_products = products | where: "type", "kitchen" %}
  class Where
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      ArrayHelpers.filter_array("where", data, args, Any.new(Array(Any).new)) do |items, matcher|
        Any.new(items.select { |i| matcher.call(i) })
      end
    end
  end

  FilterRegister.register "where", Where
end
