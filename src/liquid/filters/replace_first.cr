require "./base"
require "./string_helpers"
require "../filters"

module Liquid::Filters
  class ReplaceFirst
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("replace_first", args, 1, 2)

      Any.new(data.to_s.sub(args[0].to_s, args[1]?.to_s))
    end
  end

  FilterRegister.register("replace_first", ReplaceFirst)
end
