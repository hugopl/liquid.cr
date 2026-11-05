require "./base"
require "./string_helpers"

module Liquid::Filters
  class RStrip
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("rstrip", args, 0)

      Any.new(data.to_s.rstrip(StringHelpers::WHITESPACE))
    end
  end

  FilterRegister.register "rstrip", RStrip
end
