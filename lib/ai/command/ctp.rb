# require 'ai/command/base'

class AI::Command::Ctp < AI::Command::Base
  VALID_METHODS = ['help']
  DEFAULT_TIMES = "1,2,3,4"

  attr_accessor :times

  def index
    if @opts.help?
      $stdout.puts slop_opts
    else
      t = @opts[:times]
      puts "CTP"

      @times = t.split(',')
      @times.map! {|t| t.to_i}
      puts @times.to_s


      # initial state {t: 0, p: [0,0,0,0,0,0,0]}
      # 0 means the person is on the left side
      # 1 means the person is on the right side (crossed the bridge)
      # the first position represents the torch
      state = {t: 0}
      visited_states = []

      state[:p] = []
      state[:p] << 0
      @times.each_with_index do |person, index|
        state[:p] << 0
      end

      # state = {time: 0, position: [1,1,1,0,0]}
      puts state.to_s

      puts valid_transitions(state).to_s

      # traverse the tree and store the paths
      # depth first search style

      # add time to the state
      # calculate the new total time on transition
      # store previously visited states and the time
      # upon revisiting a visited state update the time to the lower of the two
      # if the revisit has a higher time terminate that transition
      # otherwise continue transition

      # when traversing keep track of state at each node/level so you can resume from node/level when finished with child nodes

    end
  end

  def valid_transitions(current_state)
    states = []
    torch = current_state[:p][0]
    if current_state[:p][0] == 0
      crossers = 2
    else
      crossers = 1
    end
    # crossers = 1
    current_state[:p].each_with_index do |p, i|
      next if i == 0 || p != torch

      state = current_state.clone
      state[:p] = current_state[:p].clone

      state[:p][0] = (torch + 1) % 2
      state[:p][i] = (torch + 1) % 2

      state[:t] += @times[i - 1]

      if crossers == 2
        state[:p].each_with_index do |q, j|
          next if j < i || q != torch

          state2 = state.clone
          state2[:p] = state[:p].clone

          state2[:p][j] = (torch + 1) % 2

          state2[:t] += @times[j - 1]

          states << state2
        end
      else
        states << state
      end
    end

    states
  end

  private

  def self.setup_options
    opts = Slop::Options.new
    opts.banner = 'Usage: ai ctp [options]'
    opts.separator ''
    opts.separator 'Ctp options:'
    opts.bool '-h', '--help', 'print options', default: false
    opts.string '-t', '--times', 'person times', default: DEFAULT_TIMES
    # opts.string '-d', '--directory', 'root directory to generate', default: DEFAULT_DIRECTORY
    # opts.bool '-m', '--minify', 'minify JSON output', default: false

    self.slop_opts = opts
    self.parser = Slop::Parser.new(opts)
  end

  setup_options
end
