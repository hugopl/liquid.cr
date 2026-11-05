require "./base"
require "./number_utils"

module Liquid::Filters
  # Filter plus
  #
  # Adds a number to another number.
  #
  # `{{ 4 | plus: 2 }}` => `6`
  #
  # Non numeric values are treated as zero, strings are converted to numbers.
  class Plus
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      raise FilterArgumentException.new("plus filter expects one argument.") if args.size != 1

      left = NumberUtils.to_number(data)
      right = NumberUtils.to_number(args.first)
      NumberUtils.to_any(NumberUtils.apply(left, right, :+))
    end
  end

  FilterRegister.register "plus", Plus
end
