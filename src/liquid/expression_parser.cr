require "./expression_lexer"
require "./expression_terms"

module Liquid
  # Parses liquid expressions into a tree of `Expression::Term`.
  #
  # Grammar (loosely based on Shopify liquid strict parser):
  #
  # ```text
  # filtered   := logical ('|' filter)*
  # filter     := identifier [':'] [argument (',' argument)*]
  # argument   := [identifier ':'] primary
  # logical    := comparison [('and' | 'or') logical]   # right associative, like Shopify liquid.
  # comparison := primary [comparison_operator primary]
  # primary    := literal | range | lookup
  # range      := '(' primary '..' primary ')'
  # lookup     := (identifier | '[' primary ']') ('.' identifier | '[' primary ']')*
  # ```
  class ExpressionParser
    alias Kind = ExpressionLexer::Kind
    alias Token = ExpressionLexer::Token

    LITERALS = {
      "nil"   => Any.new(nil),
      "null"  => Any.new(nil),
      "true"  => Any.new(true),
      "false" => Any.new(false),
    }

    @tokens : Array(Token)
    @pos = 0

    def initialize(@expr : String)
      @tokens = ExpressionLexer.tokenize(@expr)
    end

    # Parses a full expression, including filters and boolean/comparison operators.
    def self.parse(expr : String) : Expression::Term
      new(expr).parse
    end

    # Parses a list of primary expressions separated by `or` or `,`, as used by the `when` tag. Returns the source
    # text of each expression.
    def self.split_list(expr : String) : Array(String)
      new(expr).split_list
    end

    def parse : Expression::Term
      return Expression::Literal.new(Any.new(nil)) if peek.kind.eos?

      term = parse_filtered
      expect(Kind::EOS)
      term
    end

    def split_list : Array(String)
      list = [] of String
      loop do
        start = peek.start
        parse_primary
        list << @expr.byte_slice(start, previous.end_pos - start)
        break unless identifier?("or") || consume?(Kind::Comma)
      end
      expect(Kind::EOS)
      list
    end

    private def peek(ahead = 0) : Token
      @tokens[@pos + ahead]? || @tokens.last
    end

    private def previous : Token
      @tokens[@pos - 1]
    end

    private def consume : Token
      token = peek
      @pos += 1 unless token.kind.eos?
      token
    end

    private def consume?(kind : Kind) : Token?
      consume if peek.kind == kind
    end

    private def identifier?(name : String) : Bool
      token = peek
      return false if !token.kind.identifier? || token.value != name

      @pos += 1
      true
    end

    private def expect(kind : Kind) : Token
      token = peek
      unexpected!(token) if token.kind != kind
      consume
    end

    private def unexpected!(token : Token) : NoReturn
      raise SyntaxError.new("Unexpected #{token} in #{@expr.inspect}.")
    end

    private def parse_filtered : Expression::Term
      term = parse_logical
      return term unless peek.kind.pipe?

      filters = [] of Expression::FilterCall
      while consume?(Kind::Pipe)
        filters << parse_filter
      end
      term = Expression::Filtered.new(term, filters)

      # Not supported by Shopify liquid, but we allow comparisons after filters, e.g.: `x | modulo: 2 == 0`.
      if op = consume?(Kind::Comparison)
        term = Expression::Comparison.new(op.value, term, parse_filtered)
      end
      term
    end

    private def parse_filter : Expression::FilterCall
      name = expect(Kind::Identifier).value
      consume?(Kind::Colon)
      args = [] of Expression::Term
      kwargs = [] of {String, Expression::Term}

      loop do
        kind = peek.kind
        break if kind.pipe? || kind.eos? || kind.comparison?

        if kind.identifier? && peek(1).kind.colon?
          arg_name = consume.value
          consume
          kwargs << {arg_name, parse_primary}
        else
          args << parse_primary
        end
        consume?(Kind::Comma)
      end
      Expression::FilterCall.new(name, args, kwargs)
    end

    private def parse_logical : Expression::Term
      left = parse_comparison
      if identifier?("and")
        Expression::And.new(left, parse_logical)
      elsif identifier?("or")
        Expression::Or.new(left, parse_logical)
      else
        left
      end
    end

    private def parse_comparison : Expression::Term
      left = parse_primary
      if op = consume?(Kind::Comparison)
        Expression::Comparison.new(op.value, left, parse_primary)
      else
        left
      end
    end

    private def parse_primary : Expression::Term
      token = peek
      case token.kind
      when .identifier?
        consume
        path = parse_lookup_path
        if path.empty?
          if literal = LITERALS[token.value]?
            return Expression::Literal.new(literal)
          elsif token.value == "blank"
            return Expression::MethodLiteral.new(:blank)
          elsif token.value == "empty"
            return Expression::MethodLiteral.new(:empty)
          end
        end
        Expression::Lookup.new(token.value, path)
      when .open_square?
        consume
        name = parse_primary
        expect(Kind::CloseSquare)
        Expression::Lookup.new(name, parse_lookup_path)
      when .string?
        consume
        Expression::Literal.new(Any.new(token.value))
      when .number?
        consume
        Expression::Literal.new(parse_number(token.value))
      when .open_round?
        consume
        range_start = parse_primary
        expect(Kind::DotDot)
        range_end = parse_primary
        expect(Kind::CloseRound)
        Expression::RangeTerm.new(range_start, range_end)
      else
        unexpected!(token)
      end
    end

    private def parse_lookup_path : Array(Expression::PathItem)
      path = [] of Expression::PathItem
      loop do
        if consume?(Kind::OpenSquare)
          path << Expression::PathItem.new(parse_primary, false)
          expect(Kind::CloseSquare)
        elsif consume?(Kind::Dot)
          name = expect(Kind::Identifier).value
          path << Expression::PathItem.new(Expression::Literal.new(Any.new(name)), true)
        else
          break
        end
      end
      path
    end

    private def parse_number(value : String) : Any
      if value.includes?('.')
        Any.new(value.to_f64)
      elsif int = value.to_i32?
        Any.new(int)
      elsif int = value.to_i64?
        Any.new(int)
      else
        Any.new(value.to_f64)
      end
    end
  end
end
