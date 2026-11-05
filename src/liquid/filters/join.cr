require "./array_helpers"

module Liquid::Filters
  # join
  #
  # Combines the items in an array into a single string using the argument as a separator, the default separator is
  # a space.
  #
  # Input
  # {% assign beatles = "John, Paul, George, Ringo" | split: ", " %}
  #
  # {{ beatles | join: " and " }}
  #
  # Output
  # John and Paul and George and Ringo
  class Join
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      ArrayHelpers.check_args("join", args, 0..1)

      glue = args.first?.try(&.to_s) || " "
      Any.new(ArrayHelpers.to_array(data).join(glue))
    end
  end

  FilterRegister.register "join", Join
end
