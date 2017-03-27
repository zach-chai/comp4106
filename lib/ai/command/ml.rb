require 'ai/command/base'
require 'graphviz'

class AI::Command::Ml < AI::Command::Base
  VALID_METHODS = ['help']

  def index
    if @opts.help?
      $stdout.puts slop_opts
    else
      @num_features = 10
      @num_classes = 4

      puts "ML"



    end
  end

  def gen_class_probabilities

  end

  def gen_dep_tree
    tree = []
    tree << Node.new(0, nil)
    tree << Node.new(1, tree[0])
    tree << Node.new(2, tree[0])
    tree << Node.new(3, tree[1])
    tree << Node.new(4, tree[1])
    tree << Node.new(5, tree[2])
    tree << Node.new(6, tree[3])
    tree << Node.new(7, tree[4])
    tree << Node.new(8, tree[2])
    tree << Node.new(9, tree[3])
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
