require 'ai/command/base'

class AI::Command::Focus < AI::Command::Base
  VALID_METHODS = ['help']
  DEFAULT_SIZE = "8"

  attr_accessor :size, :board

  def index
    if @opts.help?
      $stdout.puts slop_opts
    else
      @size = @opts[:size].to_i

      puts @size

      @board = Board.new(@size)
      puts @board.board.to_s
    end
  end

  class Board

    attr_accessor :board

    def initialize(size)
      size2 = size-2
      size4 = size-4
      @board = Array.new(size/2, Array.new(size))
      @board.unshift(Array.new(size2)) if size2 > 0
      @board.unshift(Array.new(size4)) if size4 > 0

      @board.push(Array.new(size2)) if size2 > 0
      @board.push(Array.new(size4)) if size4 > 0
    end

    def move(src, dest)

    end

    def populate

    end
  end

  private

  def self.setup_options
    opts = Slop::Options.new
    opts.banner = 'Usage: ai smp [options]'
    opts.separator ''
    opts.separator 'Smp options:'
    opts.bool '-h', '--help', 'print options', default: false
    opts.string '-s', '--size', 'size e.g. 3x3', default: DEFAULT_SIZE


    self.slop_opts = opts
    self.parser = Slop::Parser.new(opts)
  end

  setup_options
end
