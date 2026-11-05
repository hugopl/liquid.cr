require "./blocks"
require "./for_loop"

module Liquid
  class RenderVisitor < Visitor
    @data : Context
    @io : IO
    @template_path : String?

    def initialize(@data = Context.new, @io = IO::Memory.new, @template_path = nil)
    end

    @[Deprecated]
    def output
      @io.to_s
    end

    def visit(node : Case)
      value = node.expression.eval(@data)
      execute_else = true
      node.blocks.each do |block|
        if block.is_a?(Else)
          block.children.each &.accept(self) if execute_else
          next
        end

        block.as(When).match?(@data, value).times do
          block.children.each &.accept(self)
          execute_else = false
        end
      end
    end

    def visit(node : If)
      if node.expression.eval(@data).raw
        node.children.each &.accept(self)
        return
      end

      elsif_arr = node.elsif
      if elsif_arr
        elsif_arr.each do |alt|
          if alt.eval(@data).raw
            alt.accept self
            return
          end
        end
      end

      node.else.try(&.accept(self))
    end

    def visit(node : Unless)
      unless node.expression.eval(@data).raw
        node.children.each &.accept(self)
        return
      end

      elsif_arr = node.elsif
      if elsif_arr
        elsif_arr.each do |alt|
          if alt.eval(@data).raw
            alt.accept self
            return
          end
        end
      end

      node.else.try(&.accept(self))
    end

    def visit(node : Node)
      node.children.each &.accept(self)
    end

    def visit(node : Assign)
      # Like Shopify liquid, the variable isn't assigned if a filter fails.
      if value = node.value.eval?(@data)
        @data.set node.varname, value
      end
    end

    def visit(node : Block::RawNode)
      @io << node.content
    end

    def visit(node : Capture)
      io = IO::Memory.new
      visitor = RenderVisitor.new @data, io, @template_path
      node.children.each &.accept visitor
      io.close
      @data.set node.var_name, io.to_s
    end

    def visit(node : Increment)
      counters = @data.registers.counters
      value = counters[node.var_name]? || 0
      counters[node.var_name] = value + 1
      @io << value
    end

    def visit(node : Decrement)
      counters = @data.registers.counters
      value = (counters[node.var_name]? || 0) - 1
      counters[node.var_name] = value
      @io << value
    end

    def visit(node : ExpressionNode)
      if node.children.empty?
        @io << node.eval(@data)
      else
        node.children.each &.accept(self)
      end
    end

    def visit(node : For)
      registers = @data.registers
      name = node.loop.name

      from = if node.offset_continue?
               registers.for_offsets[name]? || 0
             elsif offset = node.offset
               value = offset.eval(@data)
               value.raw.nil? ? 0 : (strict_integer(value) || return)
             else
               0
             end
      collection = node.collection.eval(@data) || [] of Any
      to = if limit = node.limit
             value = limit.eval(@data)
             value.raw.nil? ? nil : (strict_integer(value) || return) + from
           end

      segment = slice_collection(collection, from, to)
      segment.reverse! if node.reversed?
      registers.for_offsets[name] = from + segment.size

      visitor = blank_for?(node) ? RenderVisitor.new(@data, IO::Memory.new, @template_path) : self
      if segment.empty?
        node.else.try(&.children.each(&.accept(visitor)))
        return
      end

      forloop = ForLoop.new(name, segment.size, registers.for_stack.last?)
      with_loop_scope("forloop", forloop) do |scope|
        registers.for_stack.push(forloop)
        begin
          segment.each do |item|
            scope[node.loop_var] = item
            interrupted = render_loop_body(node.children, visitor)
            forloop.increment!
            break if interrupted
          end
        ensure
          registers.for_stack.pop
        end
      end
    end

    def visit(node : Tablerow)
      collection = node.collection.eval(@data)
      return if collection.nil?

      from = (offset = node.offset) ? (lax_integer(offset.eval(@data)) || return) : 0
      to = (limit = node.limit) ? (lax_integer(limit.eval(@data)) || return) + from : nil
      segment = slice_collection(collection, from, to)
      cols = (cols_expr = node.cols) ? (lax_integer(cols_expr.eval(@data)) || return) : segment.size

      tablerowloop = TablerowLoop.new(segment.size, cols)
      @io << %(<tr class="row1">\n)
      with_loop_scope("tablerowloop", tablerowloop) do |scope|
        segment.each do |item|
          scope[node.loop_var] = item
          @io << %(<td class="col) << tablerowloop.col << %(">)
          interrupted = render_loop_body(node.children, self)
          @io << "</td>"
          break if interrupted

          if tablerowloop.col_last && !tablerowloop.last
            @io << %(</tr>\n<tr class="row) << tablerowloop.row + 1 << %(">)
          end
          tablerowloop.increment!
        end
      end
      @io << "</tr>\n"
    end

    def visit(node : Break)
      raise BreakInterrupt.new
    end

    def visit(node : Continue)
      raise ContinueInterrupt.new
    end

    def visit(node : Cycle)
      key = (name = node.name) ? name.eval(@data) : Any.new(node.key)
      cycles = @data.registers.cycles
      iteration = cycles[key]? || 0

      raw = node.values[iteration]?.try(&.eval(@data).raw)
      @io << (raw.is_a?(Array) ? raw.join : raw.to_s)

      iteration += 1
      iteration = 0 if iteration >= node.values.size
      cycles[key] = iteration
    end

    def visit(node : IfChanged)
      io = IO::Memory.new
      visitor = RenderVisitor.new(@data, io, @template_path)
      node.children.each &.accept(visitor)
      output = io.to_s

      registers = @data.registers
      return if output == registers.ifchanged

      registers.ifchanged = output
      @io << output
    end

    # Renders a loop iteration, returns true if the loop must stop due to a `{% break %}`.
    private def render_loop_body(nodes : Array(Node), visitor : RenderVisitor) : Bool
      nodes.each &.accept(visitor)
      false
    rescue BreakInterrupt
      true
    rescue ContinueInterrupt
      false
    end

    # Pushes a local scope with the loop object (forloop, tablerowloop), the loop variable must be set in the
    # yielded scope, so it goes out of scope after the loop.
    private def with_loop_scope(loop_object_name : String, loop_object : Drop, &)
      registers = @data.registers
      scope = {loop_object_name => Any.new(loop_object)}
      registers.loop_depth += 1
      begin
        @data.with_scope(scope) { yield scope }
      ensure
        registers.loop_depth -= 1
      end
    end

    private def slice_collection(collection : Array(Any), from : Int32, to : Int32?) : Array(Any)
      start = {from, 0}.max
      stop = to ? {to, collection.size}.min : collection.size
      stop > start ? collection[start...stop] : [] of Any
    end

    # Integer conversion used by for tag attributes, like Shopify's Utils.to_integer.
    private def strict_integer(value : Any) : Int32?
      raw = value.raw
      int = case raw
            when Int    then raw.to_i
            when String then raw.strip.to_i?
            end
      @data.add_error(InvalidExpression.new("invalid integer")) if int.nil?
      int
    end

    # Integer conversion used by tablerow tag attributes, like Ruby's `to_i`.
    private def lax_integer(value : Any) : Int32?
      raw = value.raw
      case raw
      when Nil    then 0
      when Int    then raw.to_i
      when Float  then raw.to_i
      when String then raw.to_i?(strict: false) || 0
      else
        @data.add_error(InvalidExpression.new("invalid integer"))
        nil
      end
    end

    private def blank_for?(node : For) : Bool
      blank_body?(node.children) && blank_body?(node.else.try(&.children) || [] of Node)
    end

    # A body is blank if it only contains whitespace and tags that don't produce output (Shopify's `blank?`).
    private def blank_body?(nodes : Array(Node)) : Bool
      nodes.all? do |node|
        case node
        when Block::RawNode
          node.content.blank?
        when Assign, Capture, Comment
          true
        when For
          blank_for?(node)
        when Conditional
          blank_body?(node.children) &&
            (node.elsif.nil? || node.elsif.not_nil!.all? { |alt| blank_body?(alt.children) }) &&
            blank_body?(node.else.try(&.children) || [] of Node)
        when Case
          (node.when.nil? || node.when.not_nil!.all? { |when_node| blank_body?(when_node.children) }) &&
            blank_body?(node.else.try(&.children) || [] of Node)
        else
          false
        end
      end
    end

    def visit(node : Include)
      template_name = node.template_name(@data)
      partial = load_partial(template_name)
      variable_name = node.alias_name || template_name.split('/').last

      # If no variable is given, the variable with the same name of the template is used, like Shopify liquid does.
      value = if variable = node.variable
                variable.eval(@data)
              else
                @data[template_name]?
              end

      scope = Hash(String, Any).new
      node.attributes.each do |key, expression|
        scope[key] = expression.eval(@data)
      end

      @data.with_scope(scope) do
        if array = value.try(&.as_a?)
          array.each do |item|
            scope[variable_name] = item
            partial.root.accept(self)
          end
        else
          scope[variable_name] = value if value
          partial.root.accept(self)
        end
      end
    end

    def visit(node : Render)
      template_name = node.template_name(@data)
      partial = load_partial(template_name)
      variable_name = node.alias_name || template_name.split('/').last

      ctx = Context.new(@data.error_mode)
      node.attributes.each do |key, expression|
        ctx.set(key, expression.eval(@data))
      end
      visitor = RenderVisitor.new(ctx, @io, @template_path)

      variable = node.variable
      value = variable.eval(@data) if variable
      collection = value.try { |v| v.as_a? || v.as_h? } if node.for_loop?
      if collection
        items = collection.is_a?(Hash) ? collection.map { |key, val| Any{key, val} } : collection
        forloop = ForLoop.new(template_name, items.size, nil)
        ctx.set("forloop", forloop)
        items.each do |item|
          ctx.set(variable_name, item)
          partial.root.accept(visitor)
          forloop.increment!
        end
      else
        ctx.set(variable_name, value) if value
        partial.root.accept(visitor)
      end
    end

    private def load_partial(template_name : String) : Template
      template_name += ".liquid" if File.extname(template_name).empty?
      template_path = @template_path
      filename = template_path ? File.join(template_path, template_name) : template_name
      Template.parse(File.read(filename))
    rescue e : File::Error
      raise LiquidException.new("Can't load partial template #{template_name.inspect}: #{e.message}")
    end
  end
end
