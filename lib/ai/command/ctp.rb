require 'ai/command/base'
require 'pqueue'

class AI::Command::Ctp < AI::Command::Base
  VALID_METHODS = ['help']
  DEFAULT_TIMES = "1,2,3,5,8,13"
  DEFAULT_SEARCH = 'astar'
  DEFAULT_HEURISTIC = 'crossed'

  attr_accessor :times, :end_position, :search_visits

  def index
    if @opts.help?
      $stdout.puts slop_opts
    else
      t = @opts[:times]
      algorithm = @opts[:algorithm]
      heuristic = @opts[:heuristic]
      puts "CTP"

      @times = t.split(',')
      @times.map! {|t| t.to_i}
      puts "Input times: #{@times}"

      @end_position = Array.new(@times.size + 1, 1)


      # initial state {t: 0, s: [0,0,0,0,0,0,0]}
      # 0 means the person is on the left side
      # 1 means the person is on the right side (crossed the bridge)
      # the first position represents the torch
      state = {t: 0}
      visited_states = []

      state[:s] = []
      state[:s] << 0
      @times.each_with_index do |person, index|
        state[:s] << 0
      end

      puts state.to_s

require 'byebug'

      result = if algorithm == 'bfs'
        breadth_first_search(state)
      elsif algorithm == 'dfs'
        depth_first_search(state)
      elsif algorithm == 'astar'
        astar_search(state, heuristic)
      end
      print_path(result)
    end
  end

  def depth_first_search(initial_state)
    best_end = {}
    node = clone_state(initial_state)
    update_search_visits(node)
    path_visits = [node]

    while true
      while true
        transitions = filter_terminated_paths(@search_visits, valid_transitions(node))
        if transitions == []
          if node[:s] == @end_position
            if best_end.empty? || best_end[:t] > node[:t]
              best_end = node
            end
          end
          break
        else
          node = transitions[0]
          update_search_visits(node)
          path_visits << node
        end
      end
      path_visits.pop
      node = path_visits.last
      if path_visits.empty?
        break
      end
    end
    best_end
  end

  def breadth_first_search(initial_state)
    best_end = {}
    node = clone_state(initial_state)
    update_search_visits(node)
    fringe = [node]

    while true
      if node[:s] == @end_position
        if best_end.empty? || best_end[:t] > node[:t]
          best_end = node
        end
      end
      update_search_visits(node)

      transitions = filter_terminated_paths(@search_visits, valid_transitions(node))

      if transitions != []
        fringe += transitions
      end

      if fringe.empty?
        break
      else
        node = fringe.pop
      end
    end
    best_end
  end

  def astar_search(initial_state, heuristic)
    best_end = {}
    node = clone_state(initial_state)
    update_search_visits(node)
    fringe = PQueue.new([]){ |a,b| a[:h] < b[:h] }
    fringe_priority_add(fringe, [node], heuristic)

    while true
      if node[:s] == @end_position
        best_end = node
        break
      end
      update_search_visits(node)

      transitions = filter_terminated_paths(@search_visits, valid_transitions(node))

      if transitions != []
        fringe_priority_add(fringe, transitions, heuristic)
      end

      if fringe.empty?
        break
      else
        node = fringe.pop
      end
    end
    best_end
  end

  def valid_transitions(current_state)
    if current_state[:s] == @end_position
        return []
    end

    states = []
    torch = current_state[:s][0]
    if current_state[:s][0] == 0
      crossers = 2
    else
      crossers = 1
    end
    # crossers = 1
    current_state[:s].each_with_index do |p, i|
      next if i == 0 || p != torch

      state = clone_state(current_state)
      state[:p] = current_state

      state[:s][0] = (torch + 1) % 2
      state[:s][i] = (torch + 1) % 2


      if crossers == 2
        state[:s].each_with_index do |q, j|
          next if j < i || q != torch

          state2 = clone_state(state)

          state2[:s][j] = (torch + 1) % 2

          state2[:t] += [@times[i - 1], @times[j - 1]].max
          states << state2
        end
      else
        state[:t] += @times[i - 1]
        states << state
      end
    end

    states
  end

  def fringe_priority_add(fringe, transitions, heuristic)
    transitions.each do |t|
      t[:d] = if heuristic == 'weighted_crossed'
        weighted_crossed(t[:s])
      elsif heuristic == 'crossed'
        crossed(t[:s])
      elsif heuristic == 'average'
        (weighted_crossed(t[:s]) + crossed(t[:s])) / 2
      end
      t[:h] = t[:d] + (t[:t] * 2)
      fringe << t
    end
  end

  def weighted_crossed(state)
    total = 0
    state.each_with_index do |t, i|
      if t == 0
        total += @times[i].to_i
      end
    end
    total
  end

  def crossed(state)
    (state.select { |e| e == 0 }).size
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
    visited["#{transition[:s].to_s}"] && visited["#{transition[:s].to_s}"][:t] <= transition[:t]
  end

  def update_search_visits(node)
    if @search_visits.nil?
      @search_visits = {}
    end
    if !@search_visits["#{node[:s].to_s}"]
      @search_visits["#{node[:s].to_s}"] = node
    elsif @search_visits["#{node[:s].to_s}"][:t] > node[:t]
      @search_visits["#{node[:s].to_s}"] = node
    end
    true
  end

  def print_path(node)
    path = []
    while node != nil
      path << {s: node[:s], t: node[:t]}
      node = node[:p]
    end
    path.reverse!
    path.each_with_index do |s, i|
      puts "Move #{i}"
      puts s.to_s
    end
  end

  def clone_state(state)
    s = state.clone
    s[:s] = state[:s].clone
    s
  end

  private

  def self.setup_options
    opts = Slop::Options.new
    opts.banner = 'Usage: ai ctp [options]'
    opts.separator ''
    opts.separator 'Ctp options:'
    opts.bool '-h', '--help', 'print options', default: false
    opts.string '-t', '--times', 'person times e.g. 1,2,3', default: DEFAULT_TIMES
    opts.string '-a', '--algorithm', 'search algorithm', default: DEFAULT_SEARCH
    opts.string '-u', '--heuristic', 'heuristic for A*', default: DEFAULT_HEURISTIC

    self.slop_opts = opts
    self.parser = Slop::Parser.new(opts)
  end

  setup_options
end
