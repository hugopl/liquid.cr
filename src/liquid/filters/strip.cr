require "./base"
require "./string_helpers"

module Liquid::Filters
  class Strip
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("strip", args, 0)

      Any.new(data.to_s.strip(StringHelpers::WHITESPACE))
    end
  end

  FilterRegister.register "strip", Strip
end
