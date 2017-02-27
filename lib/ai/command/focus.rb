require 'ai/command/base'
require 'byebug'

class AI::Command::Focus < AI::Command::Base
  VALID_METHODS = ['help']
  DEFAULT_SIZE = 8
  SMALL_SIZE = 4
  PLAYER_ONE = 0
  PLAYER_TWO = 1

  attr_accessor :size, :board

  def index
    if @opts.help?
      $stdout.puts slop_opts
    else
      @size = @opts[:size].to_i

      puts @size

      @board = Board.new(@size)
      @board.populate
      puts @board.board.to_s

    end
  end

  class Board

    attr_accessor :board, :size

    def initialize(size)
      @size = size
      size2 = size-2
      size4 = size-4

      @board = Array.new(size/2)
      @board.map! do |arr|
        Array.new(size)
      end
      @board.unshift(Array.new(size2)) if size2 > 0
      @board.unshift(Array.new(size4)) if size4 > 0

      @board.push(Array.new(size2)) if size2 > 0
      @board.push(Array.new(size4)) if size4 > 0
    end

    def move(src, dest)

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
                nil
              else
                if count > 1 && count % 2 == 0
                  player = if player == PLAYER_ONE
                    PLAYER_TWO
                  else
                    PLAYER_ONE
                  end
                end
                count += 1
                player
              end
            end
          end
        end
      end
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
