require 'ai/command/base'

class AI::Command::Smp < AI::Command::Base
  VALID_METHODS = ['help']
  DEFAULT_SIZE = "2x2"
  DEFAULT_SPACES = '1'
  SPACE = 0

  attr_accessor :end_state, :search_visits

  def index
    if @opts.help?
      $stdout.puts slop_opts
    else
      board_size = @opts[:size]
      blank_spaces = @opts[:blank].to_i
      puts "SMP"

      @end_state = generate_board(board_size, blank_spaces)
      board = generate_board(board_size, blank_spaces, true)
      puts @end_state.to_s
      puts board.to_s


    end
  end

  def generate_board(size, spaces, random = false)
    require 'byebug'
    board = []
    b = size.split('x')
    b[0] = b[0].to_i
    b[1] = b[1].to_i
    
    a = (1..b[0]*b[1]).to_a
    if random
      a.shuffle!
    end
    spaces.times do
      i = a.find_index(a.max)
      a[i] = SPACE
    end
    length = b[0]
    b[1].times do |i|
      first = i * b[0]
      board << a[first, length]
    end
    board
  end

  def filter_terminated_paths(visited, transitions)
    filtered = []
    transitions.each do |t|
      if !terminated_path?(visited, t)
        filtered << t
      end
    end
    filtered
  end

  def terminated_path?(visited, transition)
    visited.each do |v|
      if v[:p] == transition[:p] && v[:t] <= transition[:t]
        return true
      end
    end
    false
  end

  def update_search_visits(state)
    @search_visits.each_with_index do |visit, index|
      if visit[:p] == state[:p] && visit[:t] > state[:t]
        @search_visits[index] = state
        return true
      end
    end
    @search_visits << clone_state(state)
    true
  end

  def clone_state(state)
    s = state.clone
    s[:p] = state[:p].clone
    s
  end

  private

  def self.setup_options
    opts = Slop::Options.new
    opts.banner = 'Usage: ai smp [options]'
    opts.separator ''
    opts.separator 'Smp options:'
    opts.bool '-h', '--help', 'print options', default: false
    opts.string '-s', '--size', 'size e.g. 3x3', default: DEFAULT_SIZE
    opts.string '-b', '--blank', 'blank spaces', default: DEFAULT_SPACES


    self.slop_opts = opts
    self.parser = Slop::Parser.new(opts)
  end

  setup_options
end
