require "base64"

require "./base"
require "./string_helpers"

module Liquid::Filters
  # :nodoc:
  module Base64Helpers
    STRICT_BASE64 = /\A(?:[A-Za-z0-9+\/]{4})*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=)?\z/

    # Decodes *input* like Ruby `Base64.strict_decode64`, raising on invalid input.
    def self.strict_decode(filter_name : String, input : String) : String
      raise FilterArgumentException.new("invalid base64 provided to #{filter_name}") unless STRICT_BASE64.matches?(input)

      String.new(Base64.decode(input))
    end
  end

  # base64_encode
  #
  # Encodes a string to Base64 format.
  #
  # Input
  # {{ "_#/." | base64_encode }}
  #
  # Output
  # XyMvLg==
  class Base64Encode
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("base64_encode", args, 0)

      Any.new(Base64.strict_encode(data.to_s))
    end
  end

  # base64_decode
  #
  # Decodes a string in Base64 format.
  #
  # Input
  # {{ "XyMvLg==" | base64_decode }}
  #
  # Output
  # _#/.
  class Base64Decode
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("base64_decode", args, 0)

      Any.new(Base64Helpers.strict_decode("base64_decode", data.to_s))
    end
  end

  # base64_url_safe_encode
  #
  # Encodes a string to URL-safe Base64 format.
  #
  # Input
  # {{ "_#/." | base64_url_safe_encode }}
  #
  # Output
  # XyMvLg==
  class Base64UrlSafeEncode
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("base64_url_safe_encode", args, 0)

      Any.new(Base64.urlsafe_encode(data.to_s, padding: true))
    end
  end

  # base64_url_safe_decode
  #
  # Decodes a string in URL-safe Base64 format, padding is optional.
  #
  # Input
  # {{ "XyMvLg==" | base64_url_safe_decode }}
  #
  # Output
  # _#/.
  class Base64UrlSafeDecode
    extend Filter

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      StringHelpers.check_args!("base64_url_safe_decode", args, 0)

      input = data.to_s
      input = input.ljust((input.size + 3) & ~3, '=') if !input.ends_with?('=') && input.size % 4 != 0
      Any.new(Base64Helpers.strict_decode("base64_url_safe_decode", input.tr("-_", "+/")))
    end
  end

  FilterRegister.register "base64_encode", Base64Encode
  FilterRegister.register "base64_decode", Base64Decode
  FilterRegister.register "base64_url_safe_encode", Base64UrlSafeEncode
  FilterRegister.register "base64_url_safe_decode", Base64UrlSafeDecode
end
