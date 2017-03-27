require 'ai/command/base'

class AI::Command::Ml < AI::Command::Base
  VALID_METHODS = ['help']

  def index
    if @opts.help?
      $stdout.puts slop_opts
    else
      @features = 10
      @classes = 4

      puts "ML"



    end
  end

  def gen_class_probabilities

  end


  class DependenceTree

    attr_accessor :list

    def initialize(list = nil)
      @list = list
    end

    def feature_node(feature)
      list[feature]
    end

    def feature_parent(feature)
      list[feature].parent()
    end

    def root_feature
      list[0]
    end
  end

  class Node

    attr_accessor :feature, :parent

    def initialize(feature, parent)
      @feature = feature
      @parent = parent
    end
  end

  private

  def self.setup_options
    opts = Slop::Options.new
    opts.banner = 'Usage: ai ml [options]'
    opts.separator ''
    opts.separator 'Smp options:'
    opts.bool '-h', '--help', 'print options', default: false


    self.slop_opts = opts
    self.parser = Slop::Parser.new(opts)
  end

  setup_options
end
