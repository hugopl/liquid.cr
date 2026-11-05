require "uri"

require "./base"
require "./string_helpers"

module Liquid::Filters
  # url_encode
  #
  # Converts any URL-unsafe characters in a string into percent-encoded characters, spaces are converted to `+`.
  #
  # Input
  # {{ "john@liquid.com" | url_encode }}
  #
  # Output
  # john%40liquid.com
  class UrlEncode
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("url_encode", args, 0)
      return data if data.raw.nil?

      # Same as Ruby's CGI.escape
      encoded = String.build do |str|
        data.to_s.each_byte do |byte|
          char = byte.unsafe_chr
          if char.ascii_alphanumeric? || char.in?('_', '.', '-', '~')
            str << char
          elsif char == ' '
            str << '+'
          else
            str << '%' << byte.to_s(16, upcase: true).rjust(2, '0')
          end
        end
      end
      Any.new(encoded)
    end
  end

  # url_decode
  #
  # Decodes a string that has been encoded as a URL or by `url_encode`.
  #
  # Input
  # {{ "%27Stop%21%27+said+Fred" | url_decode }}
  #
  # Output
  # 'Stop!' said Fred
  class UrlDecode
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("url_decode", args, 0)
      return data if data.raw.nil?

      decoded = URI.decode_www_form(data.to_s)
      raise FilterArgumentException.new("url_decode filter: invalid byte sequence in UTF-8") unless decoded.valid_encoding?

      Any.new(decoded)
    end
  end

  FilterRegister.register "url_encode", UrlEncode
  FilterRegister.register "url_decode", UrlDecode
end
