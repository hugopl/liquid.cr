require "./base"
require "./number_utils"

module Liquid::Filters
  # Filter round
  #
  # Rounds a number to the nearest integer or, if a number is passed as an argument, to that number of decimal places.
  # Halves are rounded away from zero.
  #
  # `{{ 1.2 | round }}` => `1`
  #
  # `{{ 2.7 | round }}` => `3`
  #
  # `{{ 183.357 | round: 2 }}` => `183.36`
  class Round
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      raise FilterArgumentException.new("round filter expects at most one argument.") if args.size > 1

      digits = args.first?.try { |arg| NumberUtils.to_integer(NumberUtils.to_number(arg)) } || 0_i64
      value = NumberUtils.to_number(data)

      result = case value
               in Int64
                 digits >= 0 ? value : round_integer(value, digits)
               in BigDecimal
                 rounded = digits >= value.scale ? value : value.round(digits, mode: :ties_away)
                 digits > 0 ? rounded : NumberUtils.to_integer(rounded)
               in Float64
                 # NaN or Infinity
                 raise FilterArgumentException.new("round filter can't round #{value}") if digits <= 0

                 value
               end
      NumberUtils.to_any(result)
    end

    private def self.round_integer(value : Int64, digits : Int64) : Int64
      return 0_i64 if digits < -18

      NumberUtils.to_integer(value.to_big_d.round(digits, mode: :ties_away))
    end
  end

  FilterRegister.register "round", Round
end
