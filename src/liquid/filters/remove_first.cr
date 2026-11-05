require "./base"
require "./string_helpers"

module Liquid::Filters
  class RemoveFirst
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("remove_first", args, 1)

      Any.new(data.to_s.sub(args.first.to_s, ""))
    end
  end

  FilterRegister.register "remove_first", RemoveFirst
end
