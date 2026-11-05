require "./array_helpers"

module Liquid::Filters
  # uniq
  #
  # Removes any duplicate items in an array, optionally comparing just a property of the items.
  #
  # Input
  # {% assign my_array = "ants, bugs, bees, bugs, ants" | split: ", " %}
  # {{ my_array | uniq | join: ", " }}
  #
  # Output
  # ants, bugs, bees
  class Uniq
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      ArrayHelpers.check_args("uniq", args, 0..1)
      items = ArrayHelpers.to_array(data)

      property = args.first?
      return Any.new(items.uniq) if property.nil? || property.raw.nil?

      Any.new(items.uniq { |item| ArrayHelpers.property_of(item, property) })
    rescue ArrayHelpers::NoPropertyLookup
      Any.new
    end
  end

  FilterRegister.register "uniq", Uniq
end
