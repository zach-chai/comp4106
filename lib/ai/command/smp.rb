require 'ai/command/base'

class AI::Command::Smp < AI::Command::Base
  VALID_METHODS = ['help']
  DEFAULT_SIZE = "3x3"
  DEFAULT_SPACES = '1'
  SPACE = 0

  attr_accessor :end_state, :search_visits, :max_x, :max_y

  def index
    if @opts.help?
      $stdout.puts slop_opts
    else
      board_size = @opts[:size]
      blank_spaces = @opts[:blank].to_i
      puts "SMP"

      b = board_size.split('x')
      @max_x = b[0].to_i
      @max_y = b[1].to_i


      @end_state = generate_board(blank_spaces)
      state = generate_board(blank_spaces, true)
      puts "Goal:"
      print_state(@end_state)
      puts "Start:"
      print_state(state)

require 'byebug'

      puts breadth_first_search(state)
      print_optimal_transitions
    end
  end

  def breadth_first_search(initial_state)
    node = {s: clone_state(initial_state), p: nil}
    update_visited_nodes(node)
    fringe = [node]

    while true
      if node[:s] == @end_state
        byebug
        return true
      end

      transitions = filter_visited_nodes(valid_transitions(node))
      fringe = transitions + fringe
      fringe -= [node]
      # fringe.pop

      if fringe == []
        break
      end

      node = fringe.last
      update_visited_nodes(node)
      # if @search_visits.size % 250 == 0
      #   byebug
      #   fringe = filter_visited_nodes(fringe)
      # end
    end
    false
  end

  def valid_transitions(current_node)
    state = clone_state(current_node[:s])
    transitions = []
    state.each_with_index do |arr, y|
      arr.each_with_index do |val, x|
        if state[y][x] == SPACE
          # swap up
          transitions << {s: swap(state, x, y, x, y+1), p: current_node} if y < @max_y - 1
          # swap right
          transitions << {s: swap(state, x, y, x+1, y), p: current_node} if x < @max_x - 1
          # swap down
          transitions << {s: swap(state, x, y, x, y-1), p: current_node} if y > 0
          # swap left
          transitions << {s: swap(state, x, y, x-1, y), p: current_node} if x > 0

          # TODO add knight move swap
        end
      end
    end
    transitions
  end

  def swap(prev_state, x1, y1, x2, y2)
    state = clone_state(prev_state)
    temp = state[y2][x2]
    state[y2][x2] = state[y1][x1]
    state[y1][x1] = temp
    state
  end

  def filter_visited_nodes(transitions)
    filtered = []
    transitions.each do |t|
      if !visited_state?(t[:s])
        filtered << t
      end
    end
    filtered
  end

  def visited_state?(state)
    @search_visits["#{state.to_s}"]
  end

  # TODO store state as key in hash map or sha1 into an array or binary search
  def update_visited_nodes(node)
    if @search_visits.nil?
      @search_visits = {}
    end
    visited_state?(node[:s])
    @search_visits["#{node[:s].to_s}"] = node
    true
  end

  def generate_board(spaces, random = false)
    board = []

    a = (1..@max_x*@max_y).to_a
    if random
      a.shuffle!
    end
    spaces.times do
      i = a.find_index(a.max)
      a[i] = SPACE
    end
    length = @max_x
    @max_y.times do |i|
      first = i * @max_x
      board << a[first, length]
    end
    board
  end

  def print_optimal_transitions()
    node = {s: @end_state}
    while node != nil
      node = @search_visits["#{node[:s].to_s}"]

      puts node[:s].to_s
      node = node[:p]
    end
  end

  def print_state(state)
    state.each do |row|
      puts row.to_s
    end
  end

  def clone_node(node)
    {s: clone_state(node[:s]), p: node[:p]}
  end

  def clone_state(state)
    state.map(&:clone) rescue nil
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
