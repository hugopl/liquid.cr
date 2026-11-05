require "./base"
require "./string_helpers"

module Liquid::Filters
  # squish
  #
  # Removes leading and trailing whitespace and collapses consecutive whitespace into a single space.
  #
  # Input
  # {{ "  Hello    World!  " | squish }}
  #
  # Output
  # Hello World!
  class Squish
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("squish", args, 0)
      return data if data.raw.nil?

      Any.new(data.to_s.strip.gsub(/\s+/, " "))
    end
  end

  FilterRegister.register "squish", Squish
end
