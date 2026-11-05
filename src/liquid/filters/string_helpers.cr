require "./base"

module Liquid::Filters
  # :nodoc:
  # Helpers shared by string filters to mimic Shopify Liquid argument handling.
  module StringHelpers
    extend self

    # Characters considered whitespace by Ruby's `String#strip`.
    WHITESPACE = " \t\n\v\f\r\0"

    # Raises a `FilterArgumentException` unless *args* size is within *min* and *max*.
    def check_args!(filter_name : String, args : Array(Any), min : Int32, max : Int32 = min) : Nil
      if args.size < min
        raise FilterArgumentException.new("#{filter_name} filter: missing argument (expected #{min}, got #{args.size})")
      elsif args.size > max
        raise FilterArgumentException.new("#{filter_name} filter: too many arguments (expected at most #{max}, got #{args.size})")
      end
    end

    # Like Shopify's `Utils.to_integer`, raises a `FilterArgumentException` if the value can't be converted to an
    # integer.
    def to_integer(filter_name : String, value : Any) : Int32
      raw = value.raw
      return raw.to_i32 if raw.is_a?(Int)

      int = raw.to_s.strip.to_i32?(underscore: true)
      raise FilterArgumentException.new("#{filter_name} filter: invalid integer #{raw.inspect}") if int.nil?

      int
    end

    # Ruby `slice(offset, length)` semantics, returns nil if *offset* is out of bounds.
    def ruby_slice_range(size : Int32, offset : Int32, length : Int32) : Range(Int32, Int32)?
      offset += size if offset < 0
      return if offset < 0 || offset > size || length < 0

      length = Math.min(length, size - offset)
      offset...(offset + length)
    end
  end
end
