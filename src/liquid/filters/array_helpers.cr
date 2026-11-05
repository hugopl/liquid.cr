require "./base"

module Liquid::Filters
  # Helpers shared by array filters, they mimic the behavior of Shopify Liquid `InputIterator` and property lookups.
  module ArrayHelpers
    extend self

    # Raised by `#property_of` when the item doesn't support property lookups at all (e.g. `nil`, booleans and floats).
    class NoPropertyLookup < Exception
    end

    # Converts the filter input to an array, the same way Shopify Liquid does:
    # - Arrays are flattened.
    # - `nil` becomes an empty array.
    # - Anything else becomes a single element array.
    def to_array(data : Any) : Array(Any)
      raw = data.raw
      case raw
      when Array
        flatten(raw)
      when Nil
        Array(Any).new
      else
        [data]
      end
    end

    # Flattens nested arrays.
    def flatten(array : Array(Any)) : Array(Any)
      return array if array.none?(&.raw.is_a?(Array))

      result = Array(Any).new(array.size)
      flatten(array, result)
      result
    end

    private def flatten(array : Array(Any), result : Array(Any)) : Nil
      array.each do |item|
        raw = item.raw
        if raw.is_a?(Array)
          flatten(raw, result)
        else
          result << item
        end
      end
    end

    # Liquid truthiness, only `nil` and `false` are falsy.
    def truthy?(value : Any) : Bool
      raw = value.raw
      !(raw.nil? || raw == false)
    end

    # Returns `true` if property lookups can be done on *item*.
    def property_lookup?(item : Any) : Bool
      case item.raw
      when Hash, Array, String, Int, Drop then true
      else                                     false
      end
    end

    # Looks up *property* on *item*, like the Ruby `item[property]` used by Shopify Liquid filters.
    #
    # Raises `FilterArgumentException` if the property can't be used to select a value from *item* and
    # `NoPropertyLookup` if *item* doesn't support property lookups.
    def property_of(item : Any, property : Any) : Any
      raw = item.raw
      prop = property.raw
      case raw
      when Hash
        prop.is_a?(String) ? raw[prop]? || Any.new : Any.new
      when Drop
        return Any.new unless prop.is_a?(String)

        begin
          raw.call(prop)
        rescue InvalidExpression
          Any.new
        end
      when String
        case prop
        when String
          raw.includes?(prop) ? Any.new(prop) : Any.new
        when Int
          char = raw[prop]?
          char ? Any.new(char.to_s) : Any.new
        else
          raise_property_error(property)
        end
      when Array
        prop.is_a?(Int) ? raw[prop]? || Any.new : raise_property_error(property)
      when Int
        prop.is_a?(Int) ? Any.new(prop >= 0 && prop < 64 ? (raw.to_i64 >> prop) & 1 : (raw < 0 ? 1 : 0)) : raise_property_error(property)
      else
        raise NoPropertyLookup.new
      end
    end

    # Common implementation of `where`, `reject`, `has`, `find` and `find_index` filters.
    #
    # Yields the input as an array and a proc that tells if an item matches the property/value given in *args*.
    # Returns *default* if the input is empty and `nil` if some item doesn't support property lookups.
    def filter_array(filter_name : String, data : Any, args : Array(Any), default : Any, &) : Any
      check_args(filter_name, args, 1..2)

      items = to_array(data)
      return default if items.empty?

      property = args[0]
      target = args[1]?
      matcher = if target.nil? || target.raw.nil?
                  ->(item : Any) { truthy?(property_of(item, property)) }
                else
                  ->(item : Any) { property_of(item, property) == target }
                end
      yield(items, matcher)
    rescue NoPropertyLookup
      Any.new
    end

    # Common implementation of `sort` and `sort_natural` filters, items are compared using the given block.
    #
    # If *property* is given, the items are sorted by this property, returns `nil` if some item doesn't support
    # property lookups.
    def sort(data : Any, property : Any?, &block : Any, Any -> Int32) : Any
      items = to_array(data)
      return Any.new(items) if items.empty?

      if property.nil? || property.raw.nil?
        Any.new(items.sort { |a, b| block.call(a, b) })
      elsif items.all? { |item| property_lookup?(item) }
        Any.new(items.sort { |a, b| block.call(property_of(a, property), property_of(b, property)) })
      else
        Any.new
      end
    end

    def raise_property_error(property : Any) : NoReturn
      raise FilterArgumentException.new("cannot select the property '#{property}'")
    end

    # Check the number of filter arguments.
    def check_args(filter_name : String, args : Array(Any), range : Range) : Nil
      return if range.includes?(args.size)

      min = range.begin
      max = range.end
      expected = if max.nil?
                   "at least #{min}"
                 elsif min == max
                   max.to_s
                 elsif min.nil? || min == 0
                   "at most #{max}"
                 else
                   "#{min} to #{max}"
                 end
      raise FilterArgumentException.new("#{filter_name} filter expects #{expected} argument#{"s" if max != 1}, got #{args.size}.")
    end
  end
end
