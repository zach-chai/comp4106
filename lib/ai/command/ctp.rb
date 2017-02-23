require 'ai/command/base'

class AI::Command::Ctp < AI::Command::Base
  VALID_METHODS = ['help']
  DEFAULT_TIMES = "1,2,3,5,8,13"

  attr_accessor :times, :end_position, :search_visits

  def index
    if @opts.help?
      $stdout.puts slop_opts
    else
      t = @opts[:times]
      puts "CTP"

      @times = t.split(',')
      @times.map! {|t| t.to_i}
      puts "Input times: #{@times}"

      @end_position = Array.new(@times.size + 1, 1)


      # initial state {t: 0, p: [0,0,0,0,0,0,0]}
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

      # puts depth_first_search(state).to_s
      puts breadth_first_search(state).to_s
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
              puts path_visits.to_s
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
      fringe -= [node]

      if fringe == []
        break
      else
        node = fringe.first
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
    # visited.each do |v|
    #   if v[:s] == transition[:s] && v[:t] <= transition[:t]
    #     return true
    #   end
    # end
    # false
    visited["#{transition[:s].to_s}"] && visited["#{transition[:s].to_s}"][:t] <= transition[:t]
  end

  def update_search_visits(node)
    # @search_visits.each_with_index do |visit, index|
    #   if visit[:s] == state[:s] && visit[:t] > state[:t]
    #     @search_visits[index] = state
    #     return true
    #   end
    # end
    # @search_visits << clone_state(state)
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

    self.slop_opts = opts
    self.parser = Slop::Parser.new(opts)
  end

  setup_options
end
