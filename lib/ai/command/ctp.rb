# require 'ai/command/base'

class AI::Command::Ctp < AI::Command::Base
  VALID_METHODS = ['help']
  DEFAULT_TIMES = "1,2,3,4"

  attr_accessor :persons

  def index
    if @opts.help?
      $stdout.puts slop_opts
    else
      times = @opts[:times]
      puts "CTP"
      puts times

      times_array = times.split(',')
      puts times_array.to_s


      # initial state [0,0,0,0,0,0,0]
      # 0 means the person is on the left side
      # 1 means the person is on the right side (crossed the bridge)
      # the first position represents the torch
      state = []
      visited_states = []

      state << 0
      times_array.each_with_index do |person, index|
        state << 0
      end

      # state = [1,1,1,0,0]
      puts state.to_s

      puts valid_transitions(state).to_s

      # traverse the tree and store the paths
      # depth first search style

    end
  end

  def valid_transitions(current_state)
    states = []
    torch = current_state[0]
    if current_state[0] == 0
      crossers = 2
    else
      crossers = 1
    end
    # crossers = 1
    current_state.each_with_index do |p, i|
      next if i == 0 || p != torch

      state = current_state.clone
      state[0] = (torch + 1) % 2
      state[i] = (torch + 1) % 2
      if crossers == 2
        state.each_with_index do |q, j|
          next if j < i || q != torch

          state2 = state.clone
          state2[j] = (torch + 1) % 2
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
