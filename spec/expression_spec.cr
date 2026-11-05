require "./spec_helper"

private class TextDrop < Drop
  def array
    Any{"text0", "text1"}
  end

  def text
    "text from drop"
  end

  private def private_method
    "bad"
  end

  private def protected_method
    "bad"
  end

  def method_with_arg(arg)
    "bad"
  end
end

private class ProductDrop < Drop
  def texts
    TextDrop.new
  end
end

private class SuperTextDrop < TextDrop
  def super_text
    "super_text"
  end
end

private def it_evaluates(expr : String, ctx : Context, expected : Liquid::Any::Type,
                         file = __FILE__, line = __LINE__)
  it "evaluates #{expr} with #{ctx} to #{expected}", file: file, line: line do
    Expression.new(expr).eval(ctx).should eq(Any.new(expected))
  end
end

private def it_raises(exception, message : String, expr : String, ctx : Context, file = __FILE__, line = __LINE__)
  it "raises #{exception}(#{message}) evaluating #{expr} with #{ctx}", file: file, line: line do
    ctx.error_mode = :strict
    expect_raises(exception, message) do
      Expression.new(expr).eval(ctx)
    end
  end
end

describe Expression do
  it_evaluates("foo", Context{"foo" => 42}, 42)
  it_evaluates("foo.blank?", Context{"foo" => ""}, true)
  it_evaluates("foo.size", Context{"foo" => Any.new("123")}, 3)
  it_evaluates("foo[0]", Context{"foo" => Any{42}}, 42)
  it_evaluates("foo[hey]", Context{"foo" => Any{"bar" => "ok"}, "hey" => Any.new("bar")}, "ok")
  it_evaluates("foo[\"bar\"]", Context{"foo" => Any{"bar" => "ok"}}, "ok")
  it_evaluates("foo[hey.ho]", Context{"foo" => Any{true}, "hey" => Any{"ho" => 0}}, true)
  it_evaluates("foo[0][1]", Context{"foo" => Any{Any{1, 42}}}, 42)

  it_evaluates("a == true", Context{"a" => true}, true)
  it_evaluates("a == true", Context{"a" => false}, false)
  it_evaluates("2 != 3", Context{"a" => true}, true)
  it_evaluates("2 != 2", Context{"a" => false}, false)
  it_evaluates("a > 2", Context{"a" => 2}, false)
  it_evaluates("a > 2", Context{"a" => 3}, true)
  it_evaluates("a >= 2", Context{"a" => 1}, false)
  it_evaluates("a >= 2", Context{"a" => 2}, true)
  it_evaluates("a < 2", Context{"a" => 2}, false)
  it_evaluates("a < 2", Context{"a" => 1}, true)
  it_evaluates("a <= 2", Context{"a" => 2}, true)
  it_evaluates("a contains b", Context{"a" => Any{1, 2}, "b" => 1}, true)
  it_evaluates("a contains b", Context{"a" => Any{1, 2}, "b" => 0}, false)
  it_evaluates("a contains b", Context{"a" => "hey ho!", "b" => "ey "}, true)

  it_evaluates("a or true", Context{"a" => false}, true)
  it_evaluates("a or false", Context{"a" => false}, false)
  it_evaluates("a and true", Context{"a" => true}, true)
  it_evaluates("a and false", Context{"a" => true}, false)

  # In lax mode these expressions must return nil and raise nothing
  it_evaluates("a > 42", Context{"a" => nil}, nil)
  it_evaluates("a[23]", Context{"a" => nil}, nil)
  it_evaluates("a.foo", Context{"a" => nil}, nil)

  # From liquid reference
  it_evaluates("true or false and false", Context.new, true)
  it_evaluates("true and false and false or true", Context.new, false)

  # Literals and lookups
  it_evaluates("'fo\\'o'", Context.new, "fo'o")
  it_evaluates("9999999999", Context.new, 9999999999_i64)
  it_evaluates("(1..3)", Context.new, Any{1, 2, 3}.raw)
  it_evaluates("(a .. 3)", Context{"a" => "2"}, Any{2, 3}.raw)
  it_evaluates("blank", Context{"blank" => "x"}, "")
  it_evaluates("blank.x", Context{"blank" => Any{"x" => 1}}, 1)
  it_evaluates("['a b']", Context{"a b" => 1}, 1)
  it_evaluates("[a]", Context{"a" => "b", "b" => 1}, 1)
  it_evaluates("a-b.size", Context{"a-b" => Any{1, 2}}, 2)
  it_evaluates("a.first", Context{"a" => "hey"}, "h")
  it_evaluates("a == empty", Context{"a" => Any{} of String => Any}, true)
  it_evaluates("a == blank", Context{"a" => " "}, true)
  it_evaluates("a contains 'k'", Context{"a" => Any{"k" => 1}}, true)
  it_evaluates("'abc' < 'acb'", Context.new, true)

  it "raises SyntaxError on invalid expressions" do
    expect_raises(SyntaxError) { Expression.new("foo..bar") }
    expect_raises(SyntaxError) { Expression.new("foo.['bar']") }
    expect_raises(SyntaxError) { Expression.new("a not b") }
  end

  # filters
  it_evaluates("'a, b, c' | split: ', ' | join '-' | upcase", Context.new, "A-B-C")

  context "when evaluating a Drop" do
    it_evaluates("drop.text", Context{"drop" => TextDrop.new}, "text from drop")
    it_evaluates("drop[\"text\"]", Context{"drop" => TextDrop.new}, "text from drop")
    it_evaluates("product.texts.array[1]", Context{"product" => ProductDrop.new}, "text1")
    it_evaluates("drop.text", Context{"drop" => SuperTextDrop.new}, "text from drop")
    it_evaluates("drop.invalid", Context{"drop" => TextDrop.new}, nil)

    it_raises(InvalidExpression, "Method private_method not found for TextDrop.",
      "drop.private_method", Context{"drop" => TextDrop.new})
    it_raises(InvalidExpression, "Method protected_method not found for TextDrop.",
      "drop.protected_method", Context{"drop" => TextDrop.new})
  end
end
