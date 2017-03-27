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

      dep_tree = DependenceTree.new(gen_dep_list)
      dep_tree.output_graph
    end
  end

  def gen_class_probabilities

  end

  def gen_dep_list
    list = []
    list << Node.new(0, nil)
    list << Node.new(1, list[0])
    list << Node.new(2, list[0])
    list << Node.new(3, list[1])
    list << Node.new(4, list[1])
    list << Node.new(5, list[2])
    list << Node.new(6, list[3])
    list << Node.new(7, list[4])
    list << Node.new(8, list[2])
    list << Node.new(9, list[3])
    list
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
      list[feature].parent
    end

    def root_feature
      list[0]
    end

    def output_graph
      g = GraphViz.new( :G, :type => :digraph )
      glist = []

      # Create two nodes
      list.each do |node|
        glist << g.add_nodes(node.feature.to_s)
      end

      # Create edges between the nodes
      list.each do |node|
        if node.parent
          g.add_edges(glist[node.parent.feature], glist[node.feature])
        end
      end

      # Generate output image
      g.output( :png => "dependence_tree.png" )
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
