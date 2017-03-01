require 'ai/command/base'
require 'pqueue'

class AI::Command::Smp < AI::Command::Base
  VALID_METHODS = ['help']
  DEFAULT_SIZE = "3x3"
  DEFAULT_SPACES = '1'
  DEFAULT_SEARCH = 'bfs'
  SPACE = 0
  DEFAULT_HEURISTIC = 'distance'

  attr_accessor :end_state, :search_visits, :max_x, :max_y

  def index
    if @opts.help?
      $stdout.puts slop_opts
    else
      board_size = @opts[:size]
      blank_spaces = @opts[:blank].to_i
      algorithm = @opts[:algorithm]
      heuristic = @opts[:heuristic]
      puts "SMP - #{algorithm}"

      b = board_size.split('x')
      @max_x = b[0].to_i
      @max_y = b[1].to_i


      @end_state = generate_board(blank_spaces)
      state = generate_board(blank_spaces, true)

      puts "Goal:"
      print_state(@end_state)
      puts "Start:"
      print_state(state)
      puts "Path:"

require 'byebug'

      if algorithm == 'bfs'
        breadth_first_search(state)
        print_optimal_transitions
      elsif algorithm == 'dfs'
        depth_first_search(state).each do |state|
          puts state.to_s
        end
      elsif algorithm == 'astar'
        astar_search(state, heuristic)
        print_optimal_transitions
      end
    end
  end

  def depth_first_search(initial_state)
    node = {s: clone_state(initial_state), p: {s: true}}
    update_visited_nodes(node)
    path_visits = [node]
    max_level = @max_y * @max_x * @max_y * @max_x
    best_path = nil

    while true
      while true
        # store solution and drop out loop
        if node[:s] == @end_state
          max_level = path_visits.size - 1
          best_path = []
          byebug
          path_visits.each do |visit|
            best_path << visit[:s]
          end
          break
        end

        # find valid, unvisited transitions
        transitions = filter_visited_nodes(valid_transitions(node))
        if node[:t]
          transitions = filter_visited_nodes(transitions, node[:t])
        end

        # if no transitions then dead end
        if transitions == []
          break
        end

        node = transitions[0]
        if max_level.nil? || path_visits.size < max_level
          update_visited_nodes(node)
          path_visits << node
        else
          break
        end

      end
      # remove_visited_nodes(path_visits.pop)
      popped_node = path_visits.pop
      if path_visits.empty?
        break
      end
      node = path_visits.last
      remove_visited_nodes(popped_node)
      if node[:t].nil?
        node[:t] = {}
      end
      node[:t]["#{popped_node[:s].to_s}"] = true
    end
    best_path
  end

  def breadth_first_search(initial_state)
    node = {s: clone_state(initial_state), p: {s: true}, d: distance(initial_state), m: 0, h: distance(initial_state)}
    update_visited_nodes(node)
    fringe = PQueue.new([node]){ |a,b| a[:h] < b[:h] }

    while true
      if node[:s] == @end_state
        return true
      end

      transitions = filter_visited_nodes(valid_transitions(node))
      fringe_bulk_add(fringe, transitions)

      if fringe.empty?
        break
      end

      while visited_state?(node[:s])
        node = fringe.pop
      end
      update_visited_nodes(node)
    end
    false
  end

  def astar_search(initial_state, heuristic)
    node = {s: clone_state(initial_state), p: {s: true}, d: distance(initial_state), m: 0, h: distance(initial_state)}
    update_visited_nodes(node)
    fringe = PQueue.new([node]){ |a,b| a[:h] < b[:h] }

    while true
      if node[:s] == @end_state
        return true
      end

      transitions = filter_visited_nodes(valid_transitions(node))
      fringe_priority_add(fringe, transitions, heuristic)

      if fringe.empty?
        break
      end

      while visited_state?(node[:s])
        node = fringe.pop
      end
      update_visited_nodes(node)
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
          # swap north-east
          transitions << {s: swap(state, x, y, x+1, y+1), p: current_node} if x < @max_x - 1 && y < @max_y - 1
          # swap south-east
          transitions << {s: swap(state, x, y, x+1, y-1), p: current_node} if x < @max_x - 1 && y > 0
          # swap south-west
          transitions << {s: swap(state, x, y, x-1, y-1), p: current_node} if x > 0 && y > 0
          # swap north-west
          transitions << {s: swap(state, x, y, x-1, y+1), p: current_node} if x > 0 && y < @max_y - 1
        else
          # Knight swap moves
          transitions << {s: swap(state, x, y, x+1, y+2), p: current_node} if y < @max_y - 2 && x < @max_x - 1 && state[y+2][x+1] != SPACE
          transitions << {s: swap(state, x, y, x-1, y+2), p: current_node} if y < @max_y - 2 && x > 0 && state[y+2][x-1] != SPACE
          transitions << {s: swap(state, x, y, x+1, y-2), p: current_node} if y > 1 && x < @max_x - 1 && state[y-2][x+1] != SPACE
          transitions << {s: swap(state, x, y, x-1, y-2), p: current_node} if y > 1 && x > 0 && state[y-2][x-1] != SPACE
          transitions << {s: swap(state, x, y, x+2, y+1), p: current_node} if x < @max_x - 2 && y < @max_y - 1 && state[y+1][x+2] != SPACE
          transitions << {s: swap(state, x, y, x+2, y-1), p: current_node} if x < @max_x - 2 && y > 0 && state[y-1][x+2] != SPACE
          transitions << {s: swap(state, x, y, x-2, y+1), p: current_node} if x > 1 && y < @max_y - 1 && state[y+1][x-2] != SPACE
          transitions << {s: swap(state, x, y, x-2, y-1), p: current_node} if x > 1 && y > 0 && state[y-1][x-2] != SPACE
        end
      end
    end
    transitions.uniq
  end

  def swap(prev_state, x1, y1, x2, y2)
    state = clone_state(prev_state)
    temp = state[y2][x2]
    state[y2][x2] = state[y1][x1]
    state[y1][x1] = temp
    state
  end

  def fringe_priority_add(fringe, transitions, heuristic)
    transitions.each do |t|
      t[:d] = if heuristic == 'distance'
        distance(t[:s]) * 0.7
      elsif heuristic == 'placed'
        placed(t[:s])
      elsif heuristic == 'average'
        (distance(t[:s]) + placed(t[:s])) / 2
      end
      t[:m] = t[:p][:m] + 1
      t[:h] = t[:d] + t[:m]
      fringe << t
    end
  end

  def fringe_bulk_add(fringe, transitions)
    transitions.each do |t|
      t[:d] = placed(t[:s])
      t[:m] = t[:p][:m] + 1
      t[:h] = t[:d] + t[:m]
      fringe << t
    end
  end

  def placed(state)
    total = 0
    div_y = @max_y + 1

    state.each_with_index do |arr, y|
      arr.each_with_index do |val, x|
        final_y = val / div_y
        final_x = (val - 1) % @max_x
        dist_y = (final_y - y).abs
        dist_x = (final_x - x).abs
        dist = dist_x > dist_y ? dist_x : dist_y
        total += 1 if dist > 0
      end
    end
    total
  end

  def distance(state)
    total = 0
    div_y = @max_y + 1

    state.each_with_index do |arr, y|
      arr.each_with_index do |val, x|
        if val == 0
          next
        end
        final_y = val / div_y
        final_x = (val - 1) % @max_x
        dist_y = (final_y - y).abs
        dist_x = (final_x - x).abs
        dist = dist_x > dist_y ? dist_x : dist_y
        total += dist
      end
    end

    total
  end

  def filter_visited_nodes(transitions, visited=@search_visits)
    filtered = []
    transitions.each do |t|
      if !visited_state?(t[:s], visited)
        filtered << t
      end
    end
    filtered
  end

  def visited_state?(state, visited=@search_visits)
    visited["#{state.to_s}"]
  end

  def update_visited_nodes(node)
    if @search_visits.nil?
      @search_visits = {}
    end
    @search_visits["#{node[:s].to_s}"] = node[:p][:s]
    true
  end

  def remove_visited_nodes(node)
    @search_visits.delete("#{node[:s].to_s}")
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
    node = @end_state
    path = []
    while node != nil && node != true
      # puts node.to_s
      path << node
      node = @search_visits["#{node.to_s}"]
    end
    path.reverse!
    path.each_with_index do |s, i|
      puts "Move #{i}"
      print_state(s)
    end
  end

  def print_state(state)
    state.each do |row|
      puts row.to_s
    end
  end

  def clone_state(state)
    state.map(&:clone) rescue nil
  end

  def factorial(num)
    (1..num).reduce(:*) || 1
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
    opts.string '-a', '--algorithm', 'search algorithm', default: DEFAULT_SEARCH
    opts.string '-u', '--heuristic', 'heuristic for A*', default: DEFAULT_HEURISTIC


    self.slop_opts = opts
    self.parser = Slop::Parser.new(opts)
  end

  setup_options
end
