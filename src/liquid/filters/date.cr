require "./base"
require "./strftime"

module Liquid::Filters
  # date
  # Converts a timestamp into another date format. The format for this syntax is the same as strftime.
  #
  # Input
  # {{ article.published_at | date: "%a, %b %d, %y" }}
  #
  # Output
  # Fri, Jul 17, 15
  #
  # Input
  # {{ article.published_at | date: "%Y" }}
  #
  # Output
  # 2015
  #
  # To get the current time, pass the special word "now" (or "today") to date:
  #
  # Input
  # This page was last updated at {{ "now" | date: "%Y-%m-%d %H:%M" }}.
  #
  # Output
  # This page was last updated at 2016-11-30 13:47.
  #
  # Note that the value will be the current time of when the page was last generated from the template, not when the page is presented to a user if caching or static site generation is involved.
  #
  # The input can be a time, a unix timestamp (integer or string), "now", "today" or a string in a common date format
  # (e.g. "2016-03-14 10:00:00 +00:00" or "March 14, 2016"), times without an explicit offset are in the local time
  # zone. If the input can't be converted to a time, or the format is empty, the input is returned unchanged.
  class Date
    extend Filter

    UNIX_TIMESTAMP_REGEX = /\A\d+\z/

    # Formats tried, in order, to parse a date string.
    PARSE_FORMATS = {
      "%Y-%m-%dT%H:%M:%S.%N%z", "%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%dT%H:%M:%S.%N", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M",
      "%Y-%m-%d %H:%M:%S.%N %z", "%Y-%m-%d %H:%M:%S %z", "%Y-%m-%d %H:%M:%S.%N%z", "%Y-%m-%d %H:%M:%S%z",
      "%Y-%m-%d %H:%M:%S.%N", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d",
      "%Y/%m/%d %H:%M:%S", "%Y/%m/%d %H:%M", "%Y/%m/%d",
      "%a, %d %b %Y %H:%M:%S %z", "%a %b %d %H:%M:%S %z %Y", "%a %b %d %H:%M:%S %Y",
      "%B %d, %Y %H:%M:%S %z", "%B %d, %Y %H:%M:%S", "%B %d, %Y %H:%M", "%B %d, %Y", "%B %d %Y",
      "%d %B %Y %H:%M:%S %z", "%d %B %Y %H:%M:%S", "%d %B %Y",
    }

    def self.filter(data : Any, args : Array(Any), options : Hash(String, Any)) : Any
      raise FilterArgumentException.new("date filter expects one argument.") if args.size != 1

      format = args.first.raw.to_s
      return data if format.empty?

      time = to_time(data)
      return data if time.nil?

      Any.new(Strftime.format(time, format))
    end

    # Converts *data* to a `Time`, returns nil if not possible.
    def self.to_time(data : Any) : Time?
      raw = data.raw
      case raw
      when Time
        raw
      when Int
        Time.unix(raw.to_i64).to_local
      when String
        str = raw.strip
        case str.downcase
        when "now", "today"
          Time.local
        when UNIX_TIMESTAMP_REGEX
          str.to_i64?.try { |timestamp| Time.unix(timestamp).to_local }
        else
          parse_time(str)
        end
      end
    rescue ArgumentError
      nil
    end

    private def self.parse_time(str : String) : Time?
      return if str.empty?

      PARSE_FORMATS.each do |format|
        return Time.parse(str, format, Time::Location.local)
      rescue Time::Format::Error
      end
      nil
    end
  end

  FilterRegister.register "date", Date
end
