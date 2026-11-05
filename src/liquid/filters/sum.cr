require "./base"
require "./number_utils"

module Liquid::Filters
  # Filter sum
  #
  # Returns the sum of all elements in an array, nested arrays are flattened. Non numeric values are treated as zero
  # and strings are converted to numbers.
  #
  # If a property name is given, the values of that property in each hash of the array are summed.
  #
  # `{{ numbers | sum }}` => `6` (where `numbers` is `[1, 2, 3]`)
  #
  # `{{ products | sum: "price" }}` => sum of all prices.
  class Sum
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      raise FilterArgumentException.new("sum filter expects at most one argument.") if args.size > 1

      property = args.first?.try(&.raw).try(&.to_s)
      total = 0_i64.as(NumberUtils::Num)
      each_item(data) do |item|
        value = property ? property_value(item, property) : item
        total = NumberUtils.apply(total, NumberUtils.to_number(value), :+)
      end
      NumberUtils.to_any(total)
    end

    private def self.each_item(data : Any, &block : Any ->) : Nil
      raw = data.raw
      case raw
      when Array
        raw.each do |item|
          item.raw.is_a?(Array) ? each_item(item, &block) : yield(item)
        end
      when Nil
      else
        yield data
      end
    end

    private def self.property_value(item : Any, property : String) : Any?
      case raw = item.raw
      when Hash   then raw[property]?
      when Drop   then raw[property]
      when String then Any.new(raw.includes?(property) ? property : nil)
      when Int, Array
        raise FilterArgumentException.new("sum filter: cannot select the property '#{property}' from #{raw.class}.")
      else
        nil
      end
    end
  end

  FilterRegister.register "sum", Sum
end
