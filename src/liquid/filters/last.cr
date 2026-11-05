require "./array_helpers"

module Liquid::Filters
  # last
  #
  # Returns the last item of an array or the last character of a string.
  class Last
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      ArrayHelpers.check_args("last", args, 0..0)

      raw = data.raw
      case raw
      when Array  then raw.last? || Any.new
      when String then Any.new(raw[-1]?.try(&.to_s) || "")
      else             Any.new
      end
    end
  end

  FilterRegister.register "last", Last
end
