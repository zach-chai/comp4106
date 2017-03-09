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
  INPUT_SEPARATOR = '.'

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
      # @board.move('b2', 'b3')
      # @board.print_state
      start_game
    end
  end

  def start_game
    input = nil
    while input != 'exit'
      puts 'Enter a move e.g. 1.b2.b3'
      input = $stdin.gets
      unless extra_pieces = @board.move(input)
        puts 'Invalid move'
        next
      end
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

    def move(input)
      input = input.split(INPUT_SEPARATOR)
      size = input[0].to_i
      src = Position.new({string: input[1]})
      dest = Position.new({string: input[2]})

      unless verify_move(size, src, dest)
        return false
      end

      extra_pieces = 0
      src_stack = stack_at_position(src)
      move_stack = src_stack[0...size]
      remain_stack = src_stack[size...src_stack.size]
      dest_stack = stack_at_position(dest)

      if pieces = src_stack.size + dest_stack.size > 5
        extra_pieces = pieces - 5
      end

      new_stack = move_stack + dest_stack
      set_position(dest, new_stack)
      set_position(src, remain_stack)

      extra_pieces
    end

    def verify_move(size, src, dest)

      # verify input is within board spec
      if size > 5 || size < 1
        return false
      elsif src.column >= 8 || src.row > 8 || dest.column >= 8 || dest.row > 8
        return false
      elsif src.column < 0 || src.row < 1 || dest.column < 0 || dest.row < 1
        return false
      end

      # verify enough pieces to move exist
      if stack_at_position(src).size < size
        return false
      end

      # verify moves are not diagonal
      if src.row != dest.row && src.column != dest.column
        return false
      end

      # verify distance within number of pieces moved
      dist = (src.row + src.column - dest.row - dest.column).abs
      if dist > size
        return false
      end

      true
    rescue => e
      puts e
      false
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
      spacing = "%15s "
      printf " %15s %15s %15s %15s %15s %15s %15s %15s\n", *(('A'..'H').to_a)
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

    def stack_at_position(pos)
      row = pos.row
      column = pos.column
      reduce = 0
      if row == 1 || row == 8
        reduce = 2
      elsif row == 2 || row == 7
        reduce = 1
      end
      board[row - 1][column - reduce]
    end

    def set_position(pos, value)
      row = pos.row
      column = pos.column
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

  class Position
    LETTERS = ('a'..'h').to_a

    attr_accessor :row, :column

    def initialize(opts = {})
      @column = letter_to_num(opts[:string][0])
      @row = opts[:string][1].to_i
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
