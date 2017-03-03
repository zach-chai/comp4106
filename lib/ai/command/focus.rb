require 'ai/command/base'
require 'byebug'

class AI::Command::Focus < AI::Command::Base
  VALID_METHODS = ['help']
  DEFAULT_SIZE = 8
  SMALL_SIZE = 4
  PLAYER_ONE = 0
  PLAYER_TWO = 1
  EMPTY_SPACE = []
  NULL_SPACE = nil

  # attr_accessor :size, :board

  def index
    if @opts.help?
      $stdout.puts slop_opts
    else
      @size = @opts[:size].to_i

      puts @size

      @board = Board.new(@size)
      @board.populate
      @board.print_state
      @board.move('b2', 'b3')
      @board.print_state
    end
  end

  class Board

    LETTERS = ('a'..'h').to_a

    attr_accessor :board, :size

    def initialize(size)
      @size = size
      size2 = size-2
      size4 = size-4

      @board = Array.new(size/2)
      @board.map! do |arr|
        Array.new(size, EMPTY_SPACE)
      end
      @board.unshift(Array.new(size2, EMPTY_SPACE)) if size2 > 0
      @board.unshift(Array.new(size4, EMPTY_SPACE)) if size4 > 0

      @board.push(Array.new(size2, EMPTY_SPACE)) if size2 > 0
      @board.push(Array.new(size4, EMPTY_SPACE)) if size4 > 0
    end

    def move(src, dest)
      extra_pieces = 0
      src_stack = position(src)
      dest_stack = position(dest)

      if pieces = src_stack.size + dest_stack.size > 5
        extra_pieces = pieces - 5
      end

      new_stack = src_stack + dest_stack
      set_position(dest, new_stack)
      set_position(src, EMPTY_SPACE)

      extra_pieces
    end

    def populate
      if size == DEFAULT_SIZE
        @board.map!.with_index do |arr, y|
          if y == 0 || y == DEFAULT_SIZE - 1
            arr
          else
            count = 0
            player = (y % 2 == 0) ? PLAYER_ONE : PLAYER_TWO
            arr.map!.with_index do |space, x|
              if arr.size == DEFAULT_SIZE && (x == 0 || x == DEFAULT_SIZE - 1)
                EMPTY_SPACE
              else
                if count > 1 && count % 2 == 0
                  player = if player == PLAYER_ONE
                    PLAYER_TWO
                  else
                    PLAYER_ONE
                  end
                end
                count += 1
                [player]
              end
            end
          end
        end
      end
    end

    def print_state
      spacing = "%10s "
      printf " %10s %10s %10s %10s %10s %10s %10s %10s\n", *(('A'..'H').to_a)
      num = 1

      board.each_with_index do |row, i|
        formatting = ""
        print num
        num += 1

        extra = (size - row.size) / 2
        edges = []
        extra.times do
          edges.push(nil)
        end

        columns = row.size + extra
        columns.times do
          formatting += spacing
        end
        formatting += "\n"
        printf formatting, *(edges + row)
      end
    end

    def position(pos)
      row = pos[1].to_i
      column = letter_to_num(pos[0])
      reduce = 0
      if row == 1 || row == 8
        reduce = 2
      elsif row == 2 || row == 7
        reduce = 1
      end
      board[row - 1][column - reduce]
    end

    def set_position(pos, value)
      row = pos[1].to_i
      column = letter_to_num(pos[0])
      reduce = 0
      if row == 1 || row == 8
        reduce = 2
      elsif row == 2 || row == 7
        reduce = 1
      end
      board[row - 1][column - reduce] = value
    end

    def letter_to_num(letter)
      LETTERS.index(letter.downcase)
    end
  end

  private

  def self.setup_options
    opts = Slop::Options.new
    opts.banner = 'Usage: ai smp [options]'
    opts.separator ''
    opts.separator 'Smp options:'
    opts.bool '-h', '--help', 'print options', default: false
    opts.string '-s', '--size', 'size e.g. 3x3', default: DEFAULT_SIZE.to_s


    self.slop_opts = opts
    self.parser = Slop::Parser.new(opts)
  end

  setup_options
end
