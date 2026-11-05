require "./base"
require "./string_helpers"

module Liquid::Filters
  #   strip_html
  #
  # Removes any HTML tags from a string.
  #
  # Input
  # {% capture string_with_html %}
  # Have <em>you</em> read <strong>Ulysses</strong>?
  # {% endcapture %}
  #
  # {{ string_with_html | strip_html }}
  #
  # Output
  # Have you read Ulysses?
  class StripHtml
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("strip_html", args, 0)

      Any.new(data.to_s.gsub(/<script.*?<\/script>|<!--.*?-->|<style.*?<\/style>/m, "").gsub(/<.*?>/m, ""))
    end
  end

  FilterRegister.register "strip_html", StripHtml
end
