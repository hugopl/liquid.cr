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
      found = false
      if when_arr = node.when
        when_arr.each do |when_node|
          when_node.match?(@data, value).times do
            when_node.children.each &.accept(self)
            found = true
          end
        end
      end
      return if found

      else_node = node.else
      else_node.children.each(&.accept(self)) if else_node
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
      @data.set node.varname, node.value.eval(@data)
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
      var = @data.get node.var_name
      if var && (num = var.as_i?)
        @data.set node.var_name, num + 1
      else
        @data.set node.var_name, 1
      end
    end

    def visit(node : Decrement)
      var = @data.get node.var_name
      if var && (num = var.as_i?)
        @data.set node.var_name, num - 1
      else
        @data.set node.var_name, -1
      end
    end

    def visit(node : ExpressionNode)
      if node.children.empty?
        @io << node.eval(@data)
      else
        node.children.each &.accept(self)
      end
    end

    def visit(node : For)
      ctx = @data.dup
      loop_over_var = node.loop_over
      loop_over = if loop_over_var.is_a?(String)
                    value = Expression.new(loop_over_var).eval(ctx)
                    value.as_a? || value.as_h? || raise InvalidStatement.new "Can't iterate over #{node.loop_over}"
                  else
                    loop_over_var
                  end

      visitor = RenderVisitor.new(ctx, @io, @template_path)
      parentloop = ctx["forloop"]?.try(&.raw).as?(ForLoop)
      forloop = ForLoop.new(loop_over, parentloop)

      ctx.set("forloop", forloop)
      forloop.each do |val|
        ctx.set(node.loop_var, val)
        node.children.each(&.accept(visitor))
      end
      ctx.set("forloop", parentloop)
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
        forloop = ForLoop.new(collection, nil)
        ctx.set("forloop", forloop)
        forloop.each do |item|
          ctx.set(variable_name, item)
          partial.root.accept(visitor)
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
