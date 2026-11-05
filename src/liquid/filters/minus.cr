require "./base"
require "./number_utils"

module Liquid::Filters
  # Filter minus
  #
  # Subtracts a number from another number.
  #
  # `{{ 4 | minus: 2 }}` => `2`
  #
  # Non numeric values are treated as zero, strings are converted to numbers.
  class Minus
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      raise FilterArgumentException.new("minus filter expects one argument.") if args.size != 1

      left = NumberUtils.to_number(data)
      right = NumberUtils.to_number(args.first)
      NumberUtils.to_any(NumberUtils.apply(left, right, :-))
    end
  end

  FilterRegister.register "minus", Minus
end
