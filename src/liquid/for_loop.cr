require "./drop"

module Liquid
  # The `forloop` object available inside `for` blocks.
  class ForLoop < Drop
    getter name : String
    getter length : Int32
    getter parentloop : ForLoop?

    def initialize(@name : String, @length : Int32, @parentloop : ForLoop?)
      @i = 0
    end

    # :nodoc:
    @[Ignore]
    def increment! : Nil
      @i += 1
    end

    def index
      @i + 1
    end

    def index0
      @i
    end

    def rindex
      length - @i
    end

    def rindex0
      length - @i - 1
    end

    def first
      @i.zero?
    end

    def last
      @i == length - 1
    end
  end

  # The `tablerowloop` object available inside `tablerow` blocks.
  class TablerowLoop < Drop
    getter length : Int32
    getter col = 1
    getter row = 1

    def initialize(@length : Int32, @cols : Int32)
      @i = 0
    end

    # :nodoc:
    @[Ignore]
    def increment! : Nil
      @i += 1
      if @col == @cols
        @col = 1
        @row += 1
      else
        @col += 1
      end
    end

    def index
      @i + 1
    end

    def index0
      @i
    end

    def col0
      @col - 1
    end

    def rindex
      length - @i
    end

    def rindex0
      length - @i - 1
    end

    def first
      @i.zero?
    end

    def last
      @i == length - 1
    end

    def col_first
      @col == 1
    end

    def col_last
      @col == @cols
    end
  end
end
