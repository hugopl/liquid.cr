require "./array_helpers"

module Liquid::Filters
  class Size
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      ArrayHelpers.check_args("size", args, 0..0)

      if (raw = data.raw) && raw.responds_to?(:size)
        Any.new raw.size
      else
        Any.new 0
      end
    end
  end

  FilterRegister.register "size", Size
end
