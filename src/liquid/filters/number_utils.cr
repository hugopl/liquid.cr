require "big"
require "../any"

module Liquid::Filters
  # Numeric coercion and arithmetic helpers shared by math filters, following Shopify Liquid semantics:
  #
  # - Integers stay integers.
  # - Floats and decimal strings (e.g. `"1.5"`) are handled as decimals (`BigDecimal`), so `10.1 - 2.2` is `7.9`.
  # - Other strings are parsed like Ruby's `String#to_i` (`"12abc"` => `12`, `"foo"` => `0`).
  # - Anything else (nil, booleans, arrays, hashes...) is `0`.
  #
  # Decimal results are converted back to `Float64`.
  module NumberUtils
    extend self

    alias Num = Int64 | BigDecimal | Float64

    DECIMAL_REGEX = /\A-?\d+\.\d+\z/
    INTEGER_REGEX = /\A\s*([+-]?\d+(?:_\d+)*)/

    # Converts *any* to an `Int64`, a `BigDecimal`, or a `Float64` (only for non-finite floats).
    def to_number(any : Any) : Num
      to_number(any.raw)
    end

    # :ditto:
    def to_number(raw) : Num
      case raw
      when Float
        raw.finite? ? BigDecimal.new(raw.to_f64.to_s) : raw.to_f64
      when Int
        raw.to_i64
      when String
        str = raw.strip
        if DECIMAL_REGEX.matches?(str)
          BigDecimal.new(str)
        elsif match = INTEGER_REGEX.match(str)
          match[1].delete('_').to_i64? || 0_i64
        else
          0_i64
        end
      else
        if raw.responds_to?(:to_number)
          to_number(raw.to_number)
        else
          0_i64
        end
      end
    end

    # Converts a numeric result to a value suitable to be stored in an `Any`.
    def to_any(value : Num) : Any
      case value
      in BigDecimal
        Any.new(value.to_f64)
      in Float64
        Any.new(value)
      in Int64
        value.in?(Int32::MIN..Int32::MAX) ? Any.new(value.to_i32) : Any.new(value)
      end
    end

    # Truncates a number to an integer.
    def to_integer(value : Num) : Int64
      case value
      in Int64      then value
      in BigDecimal then value.to_big_i.to_i64
      in Float64    then value.nan? ? 0_i64 : value.clamp(Int64::MIN.to_f, Int64::MAX.to_f).to_i64
      end
    end

    # Applies *operation* (`:+`, `:-`, `:*` or `:%`) to *left* and *right*.
    def apply(left : Num, right : Num, operation : Symbol) : Num
      if left.is_a?(Int64) && right.is_a?(Int64)
        apply_int(left, right, operation)
      elsif left.is_a?(Float64) || right.is_a?(Float64)
        apply_float(left.to_f64, right.to_f64, operation)
      else
        apply_decimal(left.to_big_d, right.to_big_d, operation)
      end
    end

    private def apply_int(left : Int64, right : Int64, operation : Symbol) : Num
      case operation
      when :+ then left + right
      when :- then left - right
      when :* then left * right
      when :%
        raise FilterArgumentException.new("divided by 0") if right.zero?
        left % right
      else raise ArgumentError.new("Unknown operation #{operation}")
      end
    rescue OverflowError
      apply_decimal(left.to_big_d, right.to_big_d, operation)
    end

    private def apply_float(left : Float64, right : Float64, operation : Symbol) : Num
      case operation
      when :+ then left + right
      when :- then left - right
      when :* then left * right
      when :%
        raise FilterArgumentException.new("divided by 0") if right.zero?
        left % right
      else raise ArgumentError.new("Unknown operation #{operation}")
      end
    end

    private def apply_decimal(left : BigDecimal, right : BigDecimal, operation : Symbol) : Num
      case operation
      when :+ then left + right
      when :- then left - right
      when :* then left * right
      when :%
        raise FilterArgumentException.new("divided by 0") if right.zero?
        left % right
      else raise ArgumentError.new("Unknown operation #{operation}")
      end
    end
  end
end
