require 'ai/command/base'
require 'graphviz'

class AI::Command::Ml < AI::Command::Base
  VALID_METHODS = ['help']
  FEATURE_LIST = 0..9

  def index
    if @opts.help?
      $stdout.puts slop_opts
    else
      @num_features = 10
      @num_classes = 4
      @num_samples = 2000

      puts "ML"

      data_generation
    end
  end

  def data_generation
    classes = []
    dep_tree = DependenceTree.new(gen_dep_list)

    @num_classes.times.with_index do |i|
      probs_list = gen_dependence_probabilities(dep_tree)
      samples = gen_samples(i, @num_samples, probs_list, dep_tree)
      classes << {probs: probs_list, samples: samples, est_probs: est_feature_probabilities(samples), est_cond_probs: est_cond_probabilities(samples)}
    end

    probs_matrix = est_cond_probabilities(classes[0][:samples])
    byebug
    # dep_tree.output_graph
  end

  # determine probability of each feature occuring (est_feature_probabilities)
  # determine probability of each feature given another feature (est_cond_probabilities)
  #   if different then we know that feature is dependent on that feature
  #   e.g. P(1) = 0.6 P(1|2) = 0.2   1 is dependent on 2
  #   the bigger the difference in probabilities the more dependent
  def est_dep_list(feature_probs, cond_probs)
    feature_probs.each_with_index do |feature_prob, feature|
      cond_probs[feature].each do |key, value|
        
      end
    end
  end

  # determines the probability of each feature occuring given another feature
  # [prob if occured, prob if not occured]
  def est_cond_probabilities(samples)
    probs_matrix = []
    total_count = samples.count
    # count the number of times feature2 is 0 given a value for feature1
    (0..9).each do |feature1|
      feature_probs_matrix = {}
      (0..9).each do |feature2|
        next if feature1 == feature2
        count_0 = samples.count {|e| e[feature2] == 0}
        count_1 = samples.count {|e| e[feature2] == 1}
        count_when_0 = samples.count {|e| e[feature2] == 0 && e[feature1] == 0}
        count_when_1 = samples.count {|e| e[feature2] == 1 && e[feature1] == 0}
        prob_f2_f1_0 = count_when_0 / count_0.to_f rescue 0
        prob_f2_f1_1 = count_when_1 / count_1.to_f rescue 0
        feature_probs_matrix[:"f#{feature2}"] = [prob_f2_f1_0.round(2), prob_f2_f1_1.round(2)]
      end
      probs_matrix << feature_probs_matrix
    end
    probs_matrix
  end

  # determines the probability of each feature occuring
  def est_feature_probabilities(samples)
    probs_matrix = []
    total_count = samples.count.to_f

    FEATURE_LIST.each do |feature|
      feature_count = samples.count {|e| e[feature] == 0}
      probs_matrix << (feature_count / total_count).round(2)
    end
    probs_matrix
  end

  def gen_dependence_probabilities(dependence_tree)
    tree = dependence_tree
    probs_list = []
    probs_list << Random.rand.round(2)
    (tree.list.count - 1).times do
      probs_list << [Random.rand.round(2), Random.rand.round(2)]
    end
    probs_list
  end

  def gen_samples(class_num, num_samples, probs_list, dep_tree)
    samples = []
    num_samples.times do
      samples << gen_sample(class_num, probs_list, dep_tree)
    end
    samples
  end

  def gen_sample(class_num, probs_list, dep_tree)
    sample = Array.new(10)
    node = dep_tree.root
    sample[node.feature] = weighted_rand(probs_list[node.feature])
    node.children.each do |child|
      gen_sample_rec(sample, child, probs_list)
    end
    sample << class_num
    sample
  end

  def gen_sample_rec(sample, node, probs_list)
    parent_sample = sample[node.parent.feature]
    sample[node.feature] = weighted_rand(probs_list[node.feature][parent_sample])
    node.children.each do |child|
      gen_sample_rec(sample, child, probs_list)
    end
  end

  def weighted_rand(prob)
    Random.rand(100) <= prob * 100 ? 0 : 1
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

    attr_accessor :list, :root

    def initialize(list = nil)
      @list = list
      @root = list.find {|n| n.parent.nil?}
      populate_children
    end

    def feature_node(feature)
      list[feature]
    end

    def feature_parent(feature)
      list[feature].parent
    end

    def populate_children
      list.each do |node|
        list.each do |child|
          if child.parent && child.parent.feature == node.feature
            node.add_child(child)
          end
        end
      end
    end

    def output_graph
      g = GraphViz.new( :G, :type => :digraph )
      glist = []

      # Create nodes
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

    attr_accessor :feature, :parent, :children

    def initialize(feature, parent)
      @feature = feature
      @parent = parent
      @children = []
    end

    def add_child(node)
      added = @children.map { |n| n.feature }
      if !added.include?(node.feature)
        @children << node
      end
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
