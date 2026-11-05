require "./array_helpers"

module Liquid::Filters
  # map
  #
  # Creates an array of values from a specific property of the items in an array. Nested arrays are flattened and
  # items without the property map to `nil`.
  #
  # Input
  # {{ site.pages | map: "category" | join: ", " }}
  class Map
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      ArrayHelpers.check_args("map", args, 1..1)

      property = args.first
      result = ArrayHelpers.to_array(data).map do |item|
        ArrayHelpers.property_of(item, property)
      rescue ArrayHelpers::NoPropertyLookup
        Any.new
      end
      Any.new(result)
    end
  end

  FilterRegister.register "map", Map
end
