require "string_scanner"
require "./exceptions"

module Liquid
  # Splits a liquid expression (the markup inside `{{ }}` or the arguments of tags like `if`) into tokens.
  #
  # The token rules follow the Shopify liquid lexer.
  class ExpressionLexer
    enum Kind
      Identifier
      Number
      String
      Comparison # ==, !=, <>, <, >, <=, >= and contains
      Dot
      DotDot
      OpenSquare
      CloseSquare
      OpenRound
      CloseRound
      Pipe
      Colon
      Comma
      Dash
      Question
      EOS
    end

    record Token, kind : Kind, value : ::String, start : Int32, end_pos : Int32 do
      def to_s(io : IO)
        if kind.eos?
          io << "end of expression"
        else
          io << value.inspect
        end
      end
    end

    private IDENTIFIER = /[a-zA-Z_][\w-]*\??/
    private NUMBER     = /-?\d+(\.\d+)?/
    private WHITESPACE = /\s*/

    def self.tokenize(expr : ::String) : Array(Token)
      new(expr).tokenize
    end

    def initialize(@expr : ::String)
      @scanner = StringScanner.new(@expr)
    end

    def tokenize : Array(Token)
      tokens = [] of Token
      scanner = @scanner
      loop do
        scanner.skip(WHITESPACE)
        break if scanner.eos?

        start = scanner.offset
        char = @expr.byte_at(start).unsafe_chr
        case char
        when '.'
          if @expr.byte_at?(start + 1) == '.'.ord
            tokens << token(Kind::DotDot, "..", start, 2)
          else
            tokens << token(Kind::Dot, ".", start, 1)
          end
        when '|' then tokens << token(Kind::Pipe, "|", start, 1)
        when ':' then tokens << token(Kind::Colon, ":", start, 1)
        when ',' then tokens << token(Kind::Comma, ",", start, 1)
        when '[' then tokens << token(Kind::OpenSquare, "[", start, 1)
        when ']' then tokens << token(Kind::CloseSquare, "]", start, 1)
        when '(' then tokens << token(Kind::OpenRound, "(", start, 1)
        when ')' then tokens << token(Kind::CloseRound, ")", start, 1)
        when '?' then tokens << token(Kind::Question, "?", start, 1)
        when '-'
          if (next_byte = @expr.byte_at?(start + 1)) && next_byte.unsafe_chr.ascii_number?
            tokens << scan_token(Kind::Number, NUMBER, start)
          else
            tokens << token(Kind::Dash, "-", start, 1)
          end
        when '=', '!'
          raise_unexpected_char(start) if @expr.byte_at?(start + 1) != '='.ord
          tokens << token(Kind::Comparison, "#{char}=", start, 2)
        when '<'
          next_byte = @expr.byte_at?(start + 1)
          if next_byte == '='.ord
            tokens << token(Kind::Comparison, "<=", start, 2)
          elsif next_byte == '>'.ord
            tokens << token(Kind::Comparison, "<>", start, 2)
          else
            tokens << token(Kind::Comparison, "<", start, 1)
          end
        when '>'
          if @expr.byte_at?(start + 1) == '='.ord
            tokens << token(Kind::Comparison, ">=", start, 2)
          else
            tokens << token(Kind::Comparison, ">", start, 1)
          end
        when '\'', '"'
          value = parse_string(char)
          tokens << Token.new(Kind::String, value, start, scanner.offset)
        else
          if char.ascii_number?
            tokens << scan_token(Kind::Number, NUMBER, start)
          elsif char.ascii_letter? || char == '_'
            tok = scan_token(Kind::Identifier, IDENTIFIER, start)
            if tok.value == "contains" && !tokens.last?.try(&.kind.dot?)
              tok = tok.copy_with(kind: Kind::Comparison)
            end
            tokens << tok
          else
            raise_unexpected_char(start)
          end
        end
      end
      tokens << Token.new(Kind::EOS, "", @expr.bytesize, @expr.bytesize)
    end

    private def token(kind : Kind, value : ::String, start : Int32, size : Int32) : Token
      @scanner.offset = start + size
      Token.new(kind, value, start, start + size)
    end

    private def scan_token(kind : Kind, regex : Regex, start : Int32) : Token
      value = @scanner.scan(regex) || raise_unexpected_char(start)
      Token.new(kind, value, start, @scanner.offset)
    end

    private def raise_unexpected_char(pos : Int32) : NoReturn
      char = @expr.byte_slice(pos).each_char.first? || ' '
      raise SyntaxError.new("Unexpected character #{char} in #{@expr.inspect}.")
    end

    # Parse a quoted string, the escape sequences `\n`, `\t` and an escaped quote are supported.
    private def parse_string(limit : Char) : ::String
      reader = Char::Reader.new(@expr, @scanner.offset + 1)
      completed = false
      handling_escape = false
      string = ::String.build do |str|
        while reader.has_next?
          char = reader.current_char
          reader.next_char
          if handling_escape
            case char
            when 'n'   then str << '\n'
            when 't'   then str << '\t'
            when limit then str << limit
            else            str << '\\' << char
            end
            handling_escape = false
          elsif char == '\\'
            handling_escape = true
          elsif char == limit
            completed = true
            break
          else
            str << char
          end
        end
      end
      raise SyntaxError.new("Unterminated string literal.") unless completed

      @scanner.offset = reader.pos
      string
    end
  end
end
