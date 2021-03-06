require 'ai/command/base'
require 'pqueue'
require 'terminal-table'

class AI::Command::Mp < AI::Command::Base
  VALID_METHODS = ['help']
  DEFAULT_TASKS = '12'
  DEFAULT_MACHINES = '3'
  DEFAULT_INCLUDE = 'bfs,dfs,astar,beam,gbfs,ucs'
  DEFAULT_EXCLUDE = ''

  def index
    if @opts.help?
      $stdout.puts slop_opts
    else
      @cost_range = 10..50
      @profit_range = 10..50
      @capacity_range = 20..60
      @num_tasks = @opts[:tasks].to_i
      @num_machines = @opts[:machines].to_i
      @include = @opts[:include].split(',')
      @exclude = @opts[:exclude].split(',')

      puts "MP"

      tasks = []
      @num_tasks.times do |task|
        profit = Random.rand(@profit_range)
        costs = generate_machine_values(@cost_range)
        tasks << Task.new(profit, costs)
      end

      machines = []
      @num_machines.times do |machine|
        machines << Machine.new(Random.rand(@capacity_range))
      end

      results = []

      if @include.include?('bfs') && !@exclude.include?('bfs')
        time_beg = Time.new
        bfs = breadth_first_search(tasks, machines)
        time_end = Time.new
        bfs[:algorithm] = "Breadth First Search"
        bfs[:time] = time_end - time_beg
        print_state(bfs[:state])
        puts "Time: #{time_end - time_beg}"
        results << bfs
      end

      if @include.include?('dfs') && !@exclude.include?('dfs')
        time_beg = Time.new
        dfs = depth_first_search(tasks, machines)
        time_end = Time.new
        dfs[:algorithm] = "Depth First Search"
        dfs[:time] = time_end - time_beg
        print_state(dfs[:state])
        results << dfs
        puts "Time: #{time_end - time_beg}"
      end

      if @include.include?('astar') && !@exclude.include?('astar')
        time_beg = Time.new
        astar = astar_search(tasks, machines, 'profit_cost')
        time_end = Time.new
        astar[:algorithm] = "A* Search"
        astar[:time] = time_end - time_beg
        print_state(astar[:state])
        results << astar
        puts "Time: #{time_end - time_beg}"
      end

      if @include.include?('beam') && !@exclude.include?('beam')
        time_beg = Time.new
        beam = beam_search(tasks, machines, 'profit_cost')
        time_end = Time.new
        beam[:algorithm] = "Beam Search"
        beam[:time] = time_end - time_beg
        print_state(beam[:state])
        results << beam
        puts "Time: #{time_end - time_beg}"
      end

      if @include.include?('gbfs') && !@exclude.include?('gbfs')
        time_beg = Time.new
        gbfs = greedy_search(tasks, machines, 'profit_per_cost')
        time_end = Time.new
        gbfs[:algorithm] = "Greedy Best First Search"
        gbfs[:time] = time_end - time_beg
        print_state(gbfs[:state])
        results << gbfs
        puts "Time: #{time_end - time_beg}"
      end

      if @include.include?('ucs') && !@exclude.include?('ucs')
        time_beg = Time.new
        ucs = uniform_cost_search(tasks, machines)
        time_end = Time.new
        ucs[:algorithm] = "Uniform Cost Search"
        ucs[:time] = time_end - time_beg
        print_state(ucs[:state])
        results << ucs
        puts "Time: #{time_end - time_beg}"
      end

      print_table(results)
    end
  end

  def breadth_first_search(tasks, machines)
    @search_visits = {}
    best_node = {}
    best_profit = 0
    node = {state: {available_tasks: tasks, machines: machines, assigned_tasks: []}}
    fringe = [node]

    while true
      if (new_profit = calc_profit(node[:state][:assigned_tasks])) > best_profit
        best_node = node
        best_profit = new_profit
      end

      update_search_visits(node)
      transitions = valid_transitions(node)
      fringe = fringe | transitions

      if fringe.empty?
        break
      else
        node = fringe.pop
      end
    end
    best_node
  end

  def depth_first_search(tasks, machines)
    @search_visits = {}
    best_node = {}
    best_profit = 0
    node = {state: {available_tasks: tasks, machines: machines, assigned_tasks: []}}
    path_visits = [node]

    while true
      while true
        transitions = valid_transitions(node)
        if transitions.empty?
          if (new_profit = calc_profit(node[:state][:assigned_tasks])) > best_profit
            best_node = node
            best_profit = new_profit
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
    best_node
  end

  def astar_search(tasks, machines, heuristic)
    @search_visits = {}
    best_node = {}
    best_profit = 0
    node = {state: {available_tasks: tasks, machines: machines, assigned_tasks: []}}
    fringe = PQueue.new([]) {|a,b| a[:heuristic] > b[:heuristic]}
    penalty = nil
    penalty_size = 0
    factor = 10

    while true
      if (new_profit = calc_profit(node[:state][:assigned_tasks])) > best_profit
        best_node = node
        best_profit = new_profit
      end

      update_search_visits(node)
      transitions = valid_transitions(node)

      if transitions.empty?
        if penalty.nil? || fringe.size > penalty_size
          penalty_size = fringe.size
          penalty = fringe.to_a[penalty_size - penalty_size / factor][:heuristic]
        end
        # puts calc_profit(node[:state][:assigned_tasks])
        # puts node[:heuristic]
        # puts penalty
        # byebug
        if node[:heuristic] < penalty
          break
        end
      else
        fringe_priority_add_astar(fringe, transitions, heuristic)
      end

      if fringe.empty?
        break
      else
        while visited_path?(node)
          node = fringe.pop
        end
      end
    end
    best_node
  rescue
    best_node
  end

  def fringe_priority_add_astar(fringe, transitions, heuristic)
    transitions.each do |t|
      if heuristic == 'profit_cost'
        value = heuristic_expected_profit(t[:state])
        cost = calc_used_capacity(t[:state][:machines])
        t[:heuristic] = (value - cost) / t[:state][:assigned_tasks].size.to_f
      else
        value = heuristic_expected_profit(t[:state])
        cost = calc_used_capacity(t[:state][:machines])
        t[:heuristic] = value - cost * 2
      end
      fringe << t
    end
  end

  def beam_search(tasks, machines, heuristic)
    @search_visits = {}
    best_node = {}
    best_profit = 0
    node = {state: {available_tasks: tasks, machines: machines, assigned_tasks: []}}
    fringe = PQueue.new([]) {|a,b| a[:heuristic] > b[:heuristic]}
    beam_size = 200

    while true
      if (new_profit = calc_profit(node[:state][:assigned_tasks])) > best_profit
        best_node = node
        best_profit = new_profit
      end

      update_search_visits(node)
      transitions = valid_transitions(node)

      if !transitions.empty?
        fringe_priority_add_beam(fringe, transitions, heuristic, beam_size)
      end

      if fringe.empty?
        break
      else
        while visited_path?(node)
          node = fringe.pop
        end
      end
    end
    best_node
  rescue
    best_node
  end

  def fringe_priority_add_beam(fringe, transitions, heuristic, size)
    transitions.each do |t|
      if heuristic == 'profit_cost'
        value = heuristic_expected_profit(t[:state])
        cost = calc_used_capacity(t[:state][:machines])
        t[:heuristic] = (value - cost) / t[:state][:assigned_tasks].size.to_f
      else
        value = heuristic_expected_profit(t[:state])
        cost = calc_used_capacity(t[:state][:machines])
        t[:heuristic] = value - cost * 2
      end
      fringe << t
      if fringe.size > size
        fringe.shift
      end
    end
  end

  def greedy_search(tasks, machines, heuristic)
    @search_visits = {}
    best_node = {}
    best_profit = 0
    node = {state: {available_tasks: tasks, machines: machines, assigned_tasks: []}}
    fringe = PQueue.new([]) {|a,b| a[:heuristic] > b[:heuristic]}

    while true
      if (new_profit = calc_profit(node[:state][:assigned_tasks])) > best_profit
        best_node = node
        best_profit = new_profit
      end

      update_search_visits(node)
      transitions = valid_transitions(node)

      if transitions.empty?
        break
      else
        fringe.clear
        fringe_priority_add_greedy(fringe, transitions, heuristic)
      end

      if fringe.empty?
        break
      else
        node = fringe.pop
      end
    end
    best_node
  end

  def fringe_priority_add_greedy(fringe, transitions, heuristic)
    transitions.each do |t|
      if heuristic == 'expected_profit'
        t[:heuristic] = heuristic_expected_profit(t[:state])
      elsif heuristic == 'profit_per_cost'
        t[:heuristic] = heuristic_expected_profit(t[:state])
      else
        t[:heuristic] = heuristic_expected_profit(t[:state])
      end
      fringe << t
    end
  end

  def heuristic_expected_profit(state)
    calc_profit(state[:assigned_tasks])
  end

  def heuristic_profit_per_cost(state)
    calc_profit(state[:assigned_tasks]) / calc_used_capacity(state[:machines]).to_f
  end

  def uniform_cost_search(tasks, machines)
    @search_visits = {}
    best_node = {}
    best_profit = 0
    node = {state: {available_tasks: tasks, machines: machines, assigned_tasks: []}}
    fringe = PQueue.new([]) {|a,b| a[:heuristic] < b[:heuristic]}

    while true
      if (new_profit = calc_profit(node[:state][:assigned_tasks])) > best_profit
        best_node = node
        best_profit = new_profit
      end

      update_search_visits(node)
      transitions = valid_transitions(node)

      if transitions.empty?
        break
      else
        transitions.each do |t|
          t[:heuristic] = calc_used_capacity(t[:state][:machines]) / t[:state][:assigned_tasks].size.to_f
          fringe << t
        end
      end

      if fringe.empty?
        break
      else
        node = fringe.pop
      end
    end
    best_node
  end

  def valid_transitions(node)
    transitions = []
    state = node[:state]
    state[:available_tasks].each_with_index do |task, task_index|
      state[:machines].each_with_index do |machine, machine_index|
        if machine.available < task.costs[machine.id]
          next
        end
        new_available = state[:available_tasks].clone
        new_assigned = state[:assigned_tasks].clone
        new_machines = state[:machines].clone
        new_machine = machine.clone

        new_machine.assign(task)
        new_machines[machine_index] = new_machine

        new_assigned << new_available.delete_at(task_index)

        transition = {state: {available_tasks: new_available, machines: new_machines, assigned_tasks: new_assigned}}
        if !visited_path?(transition)
          transitions << transition
        end
      end
    end
    transitions
  end

  def visited_path?(transition)
    !@search_visits[state_hash(transition[:state])].nil?
  end

  def update_search_visits(node)
    state = node[:state]
    profit = calc_profit(state[:assigned_tasks])
    hash = state_hash(state)
    if !@search_visits[hash]
      @search_visits[hash] = profit
    end
    true
  end

  def state_hash(state)
    profit = calc_profit(state[:assigned_tasks])
    "#{profit}#{state[:machines].map(&:available)}#{state[:available_tasks].map(&:id).sort}"
  end

  def calc_available_capacity(machines)
    machines.sum {|m| m.available}
  end

  def calc_used_capacity(machines)
    machines.sum {|m| m.used}
  end

  def calc_profit(tasks)
    tasks.sum {|t| t.profit}
  end

  def generate_machine_values(range)
    rand = Random.new
    values = []
    @num_machines.times do |machine|
      values << rand(range)
    end
    values
  end

  def print_table(results)
    heading = ['Algorithm', 'Profit', 'Time']
    rows = []
    results.each do |result|
      profit = calc_profit(result[:state][:assigned_tasks])
      rows << [result[:algorithm], profit, result[:time]]
    end
    table = Terminal::Table.new headings: heading, rows: rows
    puts table
  end

  def print_state(state)
    print "P: #{calc_profit(state[:assigned_tasks])} "
    print "Available: ["
    state[:available_tasks].each do |task|
      print " #{task.profit}"
    end

    print " ] Assigned: ["
    state[:assigned_tasks].each do |task|
      print " #{task.profit}"
    end

    print " ] Machines: ["
    state[:machines].each do |machine|
      print " #{machine.used}/#{machine.capacity}"
    end
    print " ]\n"
  end

  class Task

    attr_accessor :id, :profit, :costs
    @@count = 0

    def initialize(profit, costs)
      @id = @@count
      @profit = profit
      @costs = costs
      @@count += 1
    end
  end

  class Machine

    attr_accessor :id, :capacity, :used, :tasks
    @@count = 0

    def initialize(capacity)
      @id = @@count
      @capacity = capacity
      @used = 0
      @tasks = []
      @@count += 1
    end

    def available
      @capacity - @used
    end

    def assign(task)
      # tasks << task
      @used += task.costs[@id]
    end

    def unassign(task)
      tasks.delete_if {|t| t.id == task.id}
      @used -= task.costs[@id]
    end
  end

  private

  def self.setup_options
    opts = Slop::Options.new
    opts.banner = 'Usage: ai smp [options]'
    opts.separator ''
    opts.separator 'Mp options:'
    opts.bool '-h', '--help', 'print options', default: false
    opts.string '-t', '--tasks', 'num tasks', default: DEFAULT_TASKS
    opts.string '-m', '--machines', 'num machines', default: DEFAULT_MACHINES
    opts.string '-i', '--include', 'algorithms to include e.g. bfs dfs astar beam gbfs ucs', default: DEFAULT_INCLUDE
    opts.string '-e', '--exclude', 'algorithms to exclude e.g. bfs dfs astar beam gbfs ucs', default: DEFAULT_EXCLUDE


    self.slop_opts = opts
    self.parser = Slop::Parser.new(opts)
  end

  setup_options
end
