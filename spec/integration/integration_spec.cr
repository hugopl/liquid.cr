require "json"
require "../spec_helper"
require "../../src/liquid/json"

# [golden-liquid](https://github.com/jg-rp/golden-liquid) is a test suite for
# liquid template, tests are found in spec/integration/golden_liquid.json, a
# list of tests that are expected to fail can be found at
# spec/integration/golden_liquid.pending (one full test name per line, lines
# starting with `#` are comments).
#
# All golden liquid tests are tagged with `golden`. Tests are run in two modes,
# using the render visitor directly (tagged with `render`) and using the
# codegen visitor (tagged with `codegen`), besides a `test-N` tag for each test,
# where N is the 1-based position of the test in golden_liquid.json.
#
# For code gen tests Crystal code is written in files like
# `spec/integration/codegen-test-XXX.cr` where XXX is the test number.
#
# Partial templates (used by `include` and `render` tags) are written to
# `spec/integration/golden-partials/test-XXX/` as `<name>.liquid` files.
class GoldenTest
  include JSON::Serializable

  getter name : String
  @template : String
  @data : JSON::Any?
  @result : String?
  @results : Array(String)?
  @invalid : Bool = false
  @templates : Hash(String, String)?
  @tags : Array(String) = [] of String

  # Name of the test group, e.g. "filters, abs" or "blank and empty".
  def group : String
    parts = @name.split(", ")
    count = {"filters", "tags"}.includes?(parts.first) && parts.size > 2 ? 2 : 1
    parts.first(count).join(", ")
  end

  # Test name without the group prefix.
  def short_name : String
    @name.lchop(group).lchop(", ")
  end

  # Test assumes the host timezone is UTC.
  def utc? : Bool
    @tags.includes?("utc")
  end

  def strict? : Bool
    @tags.includes?("strict") || @tags.includes?("strict2")
  end

  def invalid? : Bool
    @invalid
  end

  private def wants : Array(String)
    @results || [@result.not_nil!]
  end

  # Golden liquid run ruby tests with `render!`, that raises an exception on first error, this is the strict behavior
  # of liquid crystal.
  private def error_mode : Context::ErrorMode
    strict? || invalid? ? Context::ErrorMode::Strict : Context::ErrorMode::Lax
  end

  private def context : Liquid::Context
    ctx = Context.new(error_mode)
    data = @data
    return ctx if data.nil?

    vars = data.as_h?
    raise "Bad context: #{data}" if vars.nil?

    vars.each do |key, value|
      ctx.set(key, value)
    end
    ctx
  end

  # Write partial templates to disk, returns the directory where they were written.
  private def write_partials(test_number) : String
    dir = Path[__DIR__, "golden-partials", "test-#{test_number}"].to_s
    Dir.mkdir_p(dir)
    @templates.try &.each do |name, source|
      path = File.join(dir, name.ends_with?(".liquid") ? name : "#{name}.liquid")
      Dir.mkdir_p(File.dirname(path))
      File.write(path, source)
    end
    dir
  end

  private def context_to_code(context : Liquid::Context) : String
    String.build do |str|
      str << "Liquid::Context.new"
      context.each do |key, value|
        str << ".tap(&.set(" << key.inspect << ", " << any_to_code(value) << "))"
      end
    end
  end

  private def any_to_code(any : Liquid::Any) : String
    raw = any.raw
    String.build do |str|
      str << "Liquid::Any.new("

      if raw.is_a?(Array)
        str << "["
        raw.each { |item| str << any_to_code(item) << ", " }
        str << "] of Liquid::Any"
      elsif raw.is_a?(Hash)
        str << "{"
        raw.each do |key, value|
          str << key.inspect << "=>" << any_to_code(value) << ", "
        end
        str << "} of String => Liquid::Any"
      else
        raw.inspect(str)
      end
      str << ")"
    end
  end

  private def render(test_number) : String
    tpl = Parser.parse(@template)
    tpl.template_path = write_partials(test_number)
    return tpl.render(context) unless utc?

    local = Time::Location.local
    begin
      Time::Location.local = Time::Location::UTC
      tpl.render(context)
    ensure
      Time::Location.local = local
    end
  end

  def test!(test_number)
    if invalid?
      expect_raises(LiquidException) do
        render(test_number)
      end
    else
      wants.should contain(render(test_number))
    end
  end

  def codegen_test!(test_number)
    test_path = Path[__DIR__, "codegen-test-#{test_number}.cr"]
    test = File.open(test_path, "w")
    test.puts("# #{@name}\n\n")
    generate_codegen_test_source(test, test_number)
    output = `crystal run #{Process.quote(test.path)} --error-trace`
    $?.exit_code.should eq(0)
    wants.should contain(output) unless invalid?
  end

  private def generate_codegen_test_source(io, test_number) : Nil
    partials_dir = write_partials(test_number)
    io.puts(<<-CRYSTAL)
    require "../../src/liquid"

    TEMPLATE =<<-LIQUID
    #{Liquid::CodeGenVisitor.escape(@template)}
    LIQUID

    #  CONTEXT
    expects_error = #{invalid?}
    context = #{context_to_code(context)}
    context.error_mode = :#{error_mode}
    #{"Time::Location.local = Time::Location::UTC" if utc?}

    #  CODEGEN OUTPUT
    CRYSTAL

    tpl = Liquid::Template.parse(@template)
    visitor = CodeGenVisitor.new(io)
    tpl.root.accept(visitor)
    io.puts(<<-CRYSTAL)
    begin
      Liquid::Template.new(root, #{partials_dir.inspect}).render(context, STDOUT)
    rescue ex : Liquid::LiquidException
      raise ex unless expects_error
    end
    CRYSTAL

  rescue ex : Liquid::LiquidException
    io << "abort(" << ex.message.inspect << ") unless expects_error\n"
  ensure
    io.close
  end
end

class GoldenLiquid
  include JSON::Serializable

  getter description : String
  getter tests : Array(GoldenTest)
end

class PendingGold
  @@pending : Set(String)?

  def self.pending?(name : String) : Bool
    pending = @@pending ||= File.read_lines(File.join(__DIR__, "golden_liquid.pending")).reject { |line| line.blank? || line.starts_with?("#") }.to_set
    pending.includes?(name)
  rescue File::NotFoundError
    false
  end
end

# Tests here use the Golden Liquid tests (https://github.com/jg-rp/golden-liquid) described at golden_liquid.json file.
describe "Golden Liquid Tests" do
  skip_pending_tests = ENV["SKIP_PENDING"]?

  golden = GoldenLiquid.from_json(File.read(File.join(__DIR__, "golden_liquid.json")))
  numbered = golden.tests.each_with_index(1).to_a
  numbered.group_by(&.[0].group).each do |group_name, tests|
    describe group_name, tags: "golden" do
      tests.each do |test, i|
        if PendingGold.pending?(test.name)
          pending(test.short_name) unless skip_pending_tests
          next
        end

        it "#{test.short_name} [test-#{i} render]", tags: ["test-#{i}", "render"] do
          test.test!(i)
        end

        it "#{test.short_name} [test-#{i} codegen]", tags: ["test-#{i}", "codegen"] do
          test.codegen_test!(i)
        end
      end
    end
  end
end
