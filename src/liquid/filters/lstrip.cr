require "./base"
require "./string_helpers"

module Liquid::Filters
  class LStrip
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("lstrip", args, 0)

      Any.new(data.to_s.lstrip(StringHelpers::WHITESPACE))
    end
  end

  FilterRegister.register "lstrip", LStrip
end
