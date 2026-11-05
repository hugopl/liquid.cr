module Liquid::Filters
  # Ruby compatible `strftime` implementation, used by the `date` filter.
  #
  # Supports the flags `-` (don't pad), `_` (pad with spaces), `0` (pad with zeros), `^` (upcase) and `#` (change case),
  # a minimum field width and the colon modifiers for `%z`.
  module Strftime
    extend self

    DAY_NAMES   = %w(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)
    MONTH_NAMES = %w(January February March April May June July August September October November December)

    def format(time : Time, format : String) : String
      String.build do |io|
        format(io, time, format)
      end
    end

    def format(io : IO, time : Time, format : String) : Nil
      chars = format.chars
      i = 0
      while i < chars.size
        char = chars[i]
        if char != '%'
          io << char
          i += 1
          next
        end

        start = i
        ok, i = directive(io, time, chars, i + 1)
        # Unknown or incomplete directive, output it verbatim.
        chars[start...i].each { |c| io << c } unless ok
      end
    end

    # Parses and outputs a directive starting at *i* (just after the `%`). Returns whether the directive is valid and
    # the position after the directive.
    private def directive(io : IO, time : Time, chars : Array(Char), i : Int32) : {Bool, Int32}
      pad : Char? = nil
      no_pad = false
      upcase = false
      swapcase = false
      colons = 0
      width : Int32? = nil

      loop do
        case chars[i]?
        when '-' then no_pad = true
        when '_' then pad = ' '
        when '0' then pad = '0'
        when '^' then upcase = true
        when '#' then swapcase = true
        else          break
        end
        i += 1
      end

      while (digit = chars[i]?.try(&.to_i?))
        # Limit the width to avoid huge outputs.
        width = Math.min((width || 0) * 10 + digit, 1024)
        i += 1
      end

      while chars[i]? == ':'
        colons += 1
        i += 1
      end

      conversion = chars[i]?
      return {false, i} if conversion.nil?

      i += 1
      return {false, i} if colons > 0 && conversion != 'z'

      case conversion
      when 'Y'
        year = time.year
        number(io, year, year < 0 ? 5 : 4, '0', pad, no_pad, width)
      when 'C' then number(io, time.year // 100, 2, '0', pad, no_pad, width)
      when 'y' then number(io, time.year % 100, 2, '0', pad, no_pad, width)
      when 'm' then number(io, time.month, 2, '0', pad, no_pad, width)
      when 'd' then number(io, time.day, 2, '0', pad, no_pad, width)
      when 'e' then number(io, time.day, 2, ' ', pad, no_pad, width)
      when 'j' then number(io, time.day_of_year, 3, '0', pad, no_pad, width)
      when 'H' then number(io, time.hour, 2, '0', pad, no_pad, width)
      when 'k' then number(io, time.hour, 2, ' ', pad, no_pad, width)
      when 'I' then number(io, hour12(time), 2, '0', pad, no_pad, width)
      when 'l' then number(io, hour12(time), 2, ' ', pad, no_pad, width)
      when 'M' then number(io, time.minute, 2, '0', pad, no_pad, width)
      when 'S' then number(io, time.second, 2, '0', pad, no_pad, width)
      when 'L' then fraction(io, time, width || 3)
      when 'N' then fraction(io, time, width || 9)
      when 'u' then number(io, time.day_of_week.value, 1, '0', pad, no_pad, width)
      when 'w' then number(io, time.day_of_week.value % 7, 1, '0', pad, no_pad, width)
      when 'G' then number(io, time.calendar_week[0], 4, '0', pad, no_pad, width)
      when 'g' then number(io, time.calendar_week[0] % 100, 2, '0', pad, no_pad, width)
      when 'V' then number(io, time.calendar_week[1], 2, '0', pad, no_pad, width)
      when 'U' then number(io, (time.day_of_year - 1 + 7 - time.day_of_week.value % 7) // 7, 2, '0', pad, no_pad, width)
      when 'W' then number(io, (time.day_of_year - 1 + 7 - (time.day_of_week.value + 6) % 7) // 7, 2, '0', pad, no_pad, width)
      when 's' then number(io, time.to_unix, 1, '0', pad, no_pad, width)
      when 'A' then text(io, DAY_NAMES[time.day_of_week.value % 7], pad, no_pad, width, upcase, swapcase)
      when 'a' then text(io, DAY_NAMES[time.day_of_week.value % 7][0, 3], pad, no_pad, width, upcase, swapcase)
      when 'B' then text(io, MONTH_NAMES[time.month - 1], pad, no_pad, width, upcase, swapcase)
      when 'b', 'h'
        text(io, MONTH_NAMES[time.month - 1][0, 3], pad, no_pad, width, upcase, swapcase)
      when 'p' then text(io, time.hour < 12 ? "AM" : "PM", pad, no_pad, width, upcase, swapcase, swap_to_lower: true)
      when 'P' then text(io, time.hour < 12 ? "am" : "pm", pad, no_pad, width, upcase, swapcase)
      when 'Z' then text(io, zone_name(time), pad, no_pad, width, upcase, swapcase, swap_to_lower: true)
      when 'z' then zone_offset(io, time, colons, pad, no_pad, width)
      when 'n' then text(io, "\n", pad, no_pad, width, false, false)
      when 't' then text(io, "\t", pad, no_pad, width, false, false)
      when '%' then text(io, "%", pad, no_pad, width, false, false)
      when 'c' then composite(io, time, "%a %b %e %H:%M:%S %Y", pad, no_pad, width, upcase, swapcase)
      when 'D', 'x'
        composite(io, time, "%m/%d/%y", pad, no_pad, width, upcase, swapcase)
      when 'F' then composite(io, time, "%Y-%m-%d", pad, no_pad, width, upcase, swapcase)
      when 'T', 'X'
        composite(io, time, "%H:%M:%S", pad, no_pad, width, upcase, swapcase)
      when 'R' then composite(io, time, "%H:%M", pad, no_pad, width, upcase, swapcase)
      when 'r' then composite(io, time, "%I:%M:%S %p", pad, no_pad, width, upcase, swapcase)
      when 'v' then composite(io, time, "%e-%^b-%4Y", pad, no_pad, width, upcase, swapcase)
      when '+' then composite(io, time, "%a %b %e %H:%M:%S %Z %Y", pad, no_pad, width, upcase, swapcase)
      else
        return {false, i}
      end
      {true, i}
    end

    private def hour12(time : Time) : Int32
      hour = time.hour % 12
      hour.zero? ? 12 : hour
    end

    private def zone_name(time : Time) : String
      time.utc? ? "UTC" : time.zone.name
    end

    private def number(io : IO, value : Int, default_width : Int32, default_pad : Char, pad : Char?, no_pad : Bool,
                       width : Int32?) : Nil
      if no_pad
        io << value
        return
      end

      pad ||= default_pad
      width ||= default_width
      digits = value.abs.to_s
      sign = value < 0 ? "-" : ""
      fill = width - digits.size - sign.size
      if pad == '0'
        io << sign
        fill.times { io << '0' }
      else
        fill.times { io << ' ' }
        io << sign
      end
      io << digits
    end

    private def fraction(io : IO, time : Time, digits : Int32) : Nil
      nanoseconds = time.nanosecond.to_s.rjust(9, '0')
      if digits <= 9
        io << nanoseconds[0, digits]
      else
        io << nanoseconds
        (digits - 9).times { io << '0' }
      end
    end

    private def text(io : IO, value : String, pad : Char?, no_pad : Bool, width : Int32?, upcase : Bool,
                     swapcase : Bool, swap_to_lower : Bool = false) : Nil
      value = value.upcase if upcase
      value = swap_to_lower ? value.downcase : value.upcase if swapcase
      if !no_pad && width && width > value.size
        (width - value.size).times { io << (pad || ' ') }
      end
      io << value
    end

    private def composite(io : IO, time : Time, format : String, pad : Char?, no_pad : Bool, width : Int32?,
                          upcase : Bool, swapcase : Bool) : Nil
      text(io, format(time, format), pad, no_pad, width, upcase, swapcase)
    end

    private def zone_offset(io : IO, time : Time, colons : Int32, pad : Char?, no_pad : Bool, width : Int32?) : Nil
      offset = time.offset
      sign = offset < 0 ? '-' : '+'
      offset = offset.abs
      hours = offset // 3600
      minutes = (offset % 3600) // 60
      seconds = offset % 60
      value = case colons
              when 0 then "%c%02d%02d" % {sign, hours, minutes}
              when 1 then "%c%02d:%02d" % {sign, hours, minutes}
              else        "%c%02d:%02d:%02d" % {sign, hours, minutes, seconds}
              end
      text(io, value, pad == '0' ? ' ' : pad, no_pad, width, false, false)
    end
  end
end
