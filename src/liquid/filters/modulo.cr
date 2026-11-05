require "./base"
require "./number_utils"

module Liquid::Filters
  # Filter modulo
  #
  # Returns the remainder of a division operation.
  #
  # `{{ 3 | modulo: 2 }}` => `1`
  #
  # Non numeric values are treated as zero, strings are converted to numbers.
  class Modulo
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      raise FilterArgumentException.new("modulo filter expects one argument.") if args.size != 1

      left = NumberUtils.to_number(data)
      right = NumberUtils.to_number(args.first)
      NumberUtils.to_any(NumberUtils.apply(left, right, :%))
    end
  end

  FilterRegister.register "modulo", Modulo
end
