require "./base"
require "./number_utils"

module Liquid::Filters
  # Filter times
  #
  # Multiplies a number by another number.
  #
  # `{{ 3 | times: 2 }}` => `6`
  #
  # Non numeric values are treated as zero, strings are converted to numbers.
  class Times
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      raise FilterArgumentException.new("times filter expects one argument.") if args.size != 1

      left = NumberUtils.to_number(data)
      right = NumberUtils.to_number(args.first)
      NumberUtils.to_any(NumberUtils.apply(left, right, :*))
    end
  end

  FilterRegister.register "times", Times
end
