require "./base"
require "./string_helpers"

module Liquid::Filters
  class Remove
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("remove", args, 1)

      Any.new(data.to_s.gsub(args.first.to_s, ""))
    end
  end

  FilterRegister.register "remove", Remove
end
