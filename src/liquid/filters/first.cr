require "./array_helpers"

module Liquid::Filters
  # first
  #
  # Returns the first item of an array, the first character of a string or the first key/value pair of a hash.
  class First
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      ArrayHelpers.check_args("first", args, 0..0)

      raw = data.raw
      case raw
      when Array  then raw.first? || Any.new
      when String then Any.new(raw[0]?.try(&.to_s) || "")
      when Hash
        tuple = raw.first?
        tuple ? Any{*tuple} : Any.new
      else
        Any.new
      end
    end
  end

  FilterRegister.register "first", First
end
