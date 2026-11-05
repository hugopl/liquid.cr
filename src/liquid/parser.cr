require "./blocks"
require "./tokenizer"
require "./strip_visitor"

module Liquid
  class Parser
    private STATEMENT = /\A\s*(?<tag>[a-z]+)\s*(?<markup>.*)\s*\z/m
    # Like Shopify liquid, the end of a raw block is the last `{% endraw %}` in a token.
    private ENDRAW_TOKEN   = /\A(?<body>.*)\{%-?\s*endraw\s*(?<rstrip>-?)%\}\z/m
    private INLINE_COMMENT = /\A\s*#(?<markup>.*)\z/m
    # Inline comments spawning multiple lines must have a `#` at the start of every line.
    private INVALID_INLINE_COMMENT = /\n\s*[^#\s]/
    # A line inside a `{% liquid %}` tag.
    private LIQUID_LINE = /\A\s*(?<tag>#|\w+)\s*(?<markup>.*?)\s*\z/m
    # Tag name of a statement token.
    private TAG_NAME = /\A\s*(\w+)/
    # Tag name of the last tag found in any token, used to find the end of `{% doc %}` and `{% raw %}` inside comments.
    private FULL_TOKEN_POSSIBLY_INVALID = /\A(?:.*)\{%-?\s*(\w+)\s*(?:.*)?-?%\}\z/m

    getter root : Root

    @str : String
    @nodes = Array(Node).new
    # if not nil we are parsing a {% raw %} block, so we keep adding the tokens to this node until we find
    # a {% endraw %}
    @raw_block : Block::RawNode?
    # Current `{% comment %}` node being parsed, its nesting level and if we are inside a `{% raw %}` inside the comment.
    @comment : Block::Comment?
    @comment_depth = 0
    @comment_raw = false
    # Current `{% doc %}` node being parsed.
    @doc : Block::Comment?

    def self.parse(str : String)
      internal = self.new str
      internal.parse
      Template.new internal.root
    end

    def self.parse(file : File)
      str = file.gets_to_end
      path = File.dirname(file.path)

      internal = self.new str
      internal.parse
      Template.new internal.root, path
    end

    def initialize(@str)
      @root = Root.new
      @last_node = @root
      @nodes << @root
    end

    # parse string
    def parse : Root
      Tokenizer.parse(@str) do |token|
        if @comment || @doc
          tag_name = token.value[TAG_NAME, 1]? if token.kind.statement?
          raw_tag_name = token.raw_value[FULL_TOKEN_POSSIBLY_INVALID, 1]?
          rstrip = token.raw_value.size >= 3 && token.raw_value[-3] == '-'
          begin
            @comment ? comment_token(tag_name, raw_tag_name, rstrip) : doc_token(raw_tag_name, rstrip)
          rescue e : SyntaxError
            e.line_number = token.line_number
            raise e
          end
          next
        end

        if raw_block = @raw_block # processing contents of {% raw %}
          if match = token.raw_value.match(ENDRAW_TOKEN)
            raw_block.content += match["body"]
            raw_block.rstrip = !match["rstrip"].empty?
            @raw_block = nil
          else
            raw_block.content += token.raw_value
          end
        elsif token.kind.raw?
          @nodes.last << Block::RawNode.new(token.value)
        elsif token.kind.expression?
          block = ExpressionNode.new(token.value)
          block.rstrip = token.rstrip?
          block.lstrip = token.lstrip?
          @nodes.last << block
        elsif token.kind.statement?
          parse_statement(token)
        end
      end

      raise SyntaxError.new("'raw' tag was never closed.") if @raw_block

      check_unclosed_comments!
      StripVisitor.new.visit(@root)
      @root
    end

    private def parse_statement(token : Token)
      token_value = token.value
      if match = token_value.match(INLINE_COMMENT)
        parse_inline_comment(match["markup"], token.lstrip?, token.rstrip?)
        return
      end

      match = token_value.match(STATEMENT)
      invalid_statement!(token) if match.nil?

      tag_name = match["tag"]
      markup = match["markup"].strip
      if tag_name == "liquid"
        parse_liquid_tag(markup, token.lstrip?, token.rstrip?)
      elsif tag_name == "raw"
        parse_raw_tag(markup, token.lstrip?)
      else
        parse_tag(tag_name, markup, token.lstrip?, token.rstrip?)
      end
    rescue e : SyntaxError
      e.line_number = token.line_number
      raise e
    end

    # Parses a tag, *floor* is the minimum size of the nodes stack, used to avoid closing blocks opened outside a
    # `{% liquid %}` tag.
    private def parse_tag(tag_name : String, markup : String, lstrip : Bool, rstrip : Bool, floor = 1) : Nil
      case tag_name
      when "comment"
        @comment = add_comment_node(lstrip, rstrip)
        @comment_depth = 1
        return
      when "doc"
        raise SyntaxError.new("Unexpected arguments in 'doc' tag.") unless markup.empty?

        @doc = add_comment_node(lstrip, rstrip)
        return
      when "echo"
        block = ExpressionNode.new(markup.empty? ? "''" : markup)
        block.lstrip = lstrip
        block.rstrip = rstrip
        @nodes.last << block
        return
      end

      block_class = BlockRegister.for_name(tag_name)
      raise SyntaxError.new("Unknown tag '#{tag_name}'.") if block_class.nil?

      block = block_class.new(markup)
      block.rstrip = rstrip
      block.lstrip = lstrip

      case block
      when Block::EndBlock
        # FIXME: Check if the end tag matches the begin tag
        raise SyntaxError.new("Unexpected tag '#{tag_name}'.") if @nodes.size <= floor

        finished_block = @nodes.pop
        finished_block.remove_blank_strings if finished_block.blank?
        @nodes.last << block
      when Block::BeginBlock
        @nodes.last << block
        @nodes << block
      when Block::InlineBlock
        @nodes.last << block
      else
        raise SyntaxError.new("Invalid tag '#{tag_name}'.")
      end
    end

    # To process {% raw %} we create a RawNode and add every token to it until we find a {% endraw %}.
    private def parse_raw_tag(markup : String, lstrip : Bool) : Nil
      raise SyntaxError.new("Syntax Error in tag 'raw' - Valid syntax: raw") unless markup.empty?

      raw_block = Block::RawNode.new("", raw_tag: true)
      raw_block.lstrip = lstrip
      @nodes.last << raw_block
      @raw_block = raw_block
    end

    private def add_comment_node(lstrip : Bool, rstrip : Bool) : Block::Comment
      node = Block::Comment.new
      node.lstrip = lstrip
      node.rstrip = rstrip
      @nodes.last << node
      node
    end

    private def parse_inline_comment(markup : String, lstrip : Bool, rstrip : Bool) : Nil
      raise SyntaxError.new("Each line of an inline comment must start with a '#'.") if markup =~ INVALID_INLINE_COMMENT

      add_comment_node(lstrip, rstrip)
    end

    # Process a token found inside a `{% comment %}` block, only nested `comment` and `raw` tags are taken into
    # account. *rstrip* is the whitespace control of the token.
    private def comment_token(tag_name : String?, raw_tag_name : String?, rstrip : Bool) : Nil
      if @comment_raw
        @comment_raw = false if raw_tag_name == "endraw"
        return
      end

      case tag_name
      when "raw"
        @comment_raw = true
      when "comment"
        @comment_depth += 1
      when "endcomment"
        @comment_depth -= 1
        if @comment_depth.zero?
          @comment.try(&.rstrip = rstrip)
          @comment = nil
        end
      end
    end

    # Process a token found inside a `{% doc %}` block.
    private def doc_token(tag_name : String?, rstrip : Bool) : Nil
      case tag_name
      when "doc"
        raise SyntaxError.new("Nested 'doc' tags are not allowed.")
      when "enddoc"
        @doc.try(&.rstrip = rstrip)
        @doc = nil
      end
    end

    private def check_unclosed_comments! : Nil
      raise SyntaxError.new("'comment' tag was never closed.") if @comment
      raise SyntaxError.new("'raw' tag was never closed.") if @comment_raw
      raise SyntaxError.new("'doc' tag was never closed.") if @doc
    end

    private def parse_liquid_tag(markup : String, lstrip : Bool, rstrip : Bool) : Nil
      node = Block::LiquidTag.new
      node.lstrip = lstrip
      node.rstrip = rstrip
      @nodes.last << node
      @nodes << node
      parse_liquid_lines(markup)
      @nodes.pop
    end

    # Parse the contents of a `{% liquid %}` tag, one tag per line.
    private def parse_liquid_lines(markup : String) : Nil
      floor = @nodes.size
      markup.each_line(chomp: true) do |line|
        next if line.blank?

        match = line.match(LIQUID_LINE)
        raise SyntaxError.new("Invalid line inside liquid tag: #{line.inspect}.") if match.nil?

        tag_name = match["tag"]
        tag_markup = match["markup"]
        if @comment
          comment_token(tag_name, tag_name, false)
        elsif @doc
          doc_token(tag_name, false)
        elsif tag_name == "#"
          next
        elsif tag_name == "liquid"
          parse_liquid_lines(tag_markup)
        else
          parse_tag(tag_name, tag_markup, false, false, floor)
        end
      end
      check_unclosed_comments!
      raise SyntaxError.new("Tag '#{@nodes.last.class.name}' was never closed inside liquid tag.") if @nodes.size != floor
    end

    private def invalid_statement!(token)
      raise InvalidStatement.new("Invalid Statement #{token.value.inspect} at line #{token.line_number}.")
    end
  end
end
