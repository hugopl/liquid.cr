require "./array_helpers"

module Liquid::Filters
  # reject
  #
  # Filters an array to exclude items with a specific property value, if no value is given items with a
  # truthy property are rejected.
  #
  # Input
  # {% assign non_kitchen_products = products | reject: "type", "kitchen" %}
  class Reject
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      ArrayHelpers.filter_array("reject", data, args, Any.new(Array(Any).new)) do |items, matcher|
        Any.new(items.reject { |i| matcher.call(i) })
      end
    end
  end

  FilterRegister.register "reject", Reject
end
