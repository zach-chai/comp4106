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
      @num_samples = 4000

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
      est_probs = est_feature_probabilities(samples)
      est_cond_probs = est_cond_probabilities(samples)
      cond_diffs = ind_cond_diff_matrix(est_probs, est_cond_probs)
      dep_stats = dep_stats(cond_diffs)
      ord_cond_diffs = ordered_cond_diffs(cond_diffs)
      est_dep_tree = est_dep_tree(ord_cond_diffs)
      classes << {probs: probs_list, samples: samples,
        est_probs: est_probs,
        est_cond_probs: est_cond_probs,
        cond_diffs: cond_diffs,
        ord_cond_diffs: ord_cond_diffs,
        est_dep_tree: est_dep_tree,
        dep_stats: dep_stats
      }
    end
    puts "probs"
    puts classes[0][:probs].to_s
    puts "est_probs"
    puts classes[0][:est_probs].to_s
    puts "est_cond_probs"
    puts classes[0][:est_cond_probs][1]
    puts "cond_diffs"
    puts classes[0][:cond_diffs][1]
    # puts "dep_stats"
    # puts classes[0][:dep_stats][:"1"]
    # puts "ord_cond_diffs"
    # puts classes[0][:ord_cond_diffs]

    byebug
    # dep_tree.output_graph
  end

  # determine probability of each feature occuring (est_feature_probabilities)
  # determine probability of each feature given another feature (est_cond_probabilities)
  #   if different then we know that feature is dependent on that feature
  #   e.g. P(1) = 0.6 P(1|2) = 0.2   1 is dependent on 2
  #   the bigger the difference in probabilities the more dependent
  def est_dep_tree(ord_cond_diffs)
    deps_list = []
    connected_node_lists = []
    deps_edge_list = []

    ord_cond_diffs.each do |diff|
      if deps_edge_list.include?(diff[:pair].reverse) || deps_edge_list.include?(diff[:pair])
        next
      elsif (connected_node_lists.select {|x| (x & diff[:pair]).size == 2}).any?
        next
      else
        deps_edge_list << diff[:pair]
        if deps_edge_list.size > 9
          byebug
        end
        join_lists = []
        connected_node_lists.each_with_index do |node_list, index|
          if (node_list & diff[:pair]).size > 0
            join_lists << index
          end
        end
        if join_lists.size == 2
          connected_node_lists[join_lists[0]] = connected_node_lists[join_lists[0]] | connected_node_lists[join_lists[1]]
          connected_node_lists.delete_at(join_lists[1])
        elsif join_lists.size == 1
          connected_node_lists[join_lists[0]] = connected_node_lists[join_lists[0]] | diff[:pair]
        elsif join_lists.size == 0
          connected_node_lists << diff[:pair]
        else
          puts "This should not happen"
          byebug
        end
      end
    end

    # initialize nodes
    FEATURE_LIST.each do |feature|
      deps_list << Node.new(feature, nil)
    end

    # set parents
    connect_tree_rec(deps_list[0], deps_edge_list, deps_list)

    DependenceTree.new(deps_list)
  end

  def connect_tree_rec(node, deps_edge_list, deps_list)
    edges = deps_edge_list.select {|e| e.include?(node.feature)}
    if node.parent
      edges = edges.reject {|e| e.include?(node.parent.feature)}
    end
    return if edges.empty?
    children = edges.flatten.uniq
    children.each do |child|
      next if node.feature == child
      deps_list[child].parent = deps_list[node.feature]
      connect_tree_rec(deps_list[child], deps_edge_list, deps_list)
    end
  end

  # flatten the diff matrix to one ordered list
  def ordered_cond_diffs(diff_matrix)
    ordered_diffs = []
    diff_matrix.each_with_index do |feature_diffs, feature1|
      feature_diffs.each do |feature2, diff|
        ordered_diffs << {pair: [feature1, feature2.to_s.to_i], weight: diff}
      end
    end
    ordered_diffs.sort {|a,b| a[:weight] < b[:weight] ? 1 : -1}
  end

  # stats on the diffs
  def dep_stats(diff_matrix)
    est_dep_feature = {}
    diff_matrix.each_with_index do |feature_diffs, feature1|
      max = 0
      max_feature = -1
      feature_diffs.each do |feature2, diff|
        if diff > max
          max = diff
          max_feature = feature2
        end
      end
      # ordered by weight
      ordered = feature_diffs.keys.zip(feature_diffs.values).sort {|a,b| a[1] < b[1] ? 1 : -1}

      # Descriptive stats
      arr_diffs = feature_diffs.values.map {|v| v * 100}
      total = arr_diffs.inject(:+)
      mean = total.to_f / arr_diffs.length
      variance = arr_diffs.inject(0){|accum, i| accum + (i - mean) ** 2}
      std_dev = Math.sqrt(variance)

      est_dep_feature[:"#{feature1}"] = {max_feature: max_feature, ordered: ordered, mean: mean, std_dev: std_dev}
    end
    est_dep_feature
  end

  # determine the difference between the independent probabilities and the conditional probabilities
  def ind_cond_diff_matrix(feature_probs, cond_probs)
    diff_matrix = []
    feature_probs.each_with_index do |feature_prob, feature|
      feature_diff_matrix = {}
      cond_probs[feature].each do |feature2, cond_probs|
        diff0 = (feature_prob - cond_probs[0]).abs
        diff1 = (feature_prob - cond_probs[1]).abs
        feature_diff_matrix[:"#{feature2}"] = (diff0 + diff1).round(2)
      end
      diff_matrix << feature_diff_matrix
    end
    diff_matrix
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
        feature_probs_matrix[:"#{feature2}"] = [prob_f2_f1_0.round(2), prob_f2_f1_1.round(2)]
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
      first_rand = Random.rand(0.1..0.9)
      while true
        second_rand = Random.rand(0.1..0.9)
        break if (first_rand - second_rand).abs > 0.1
      end
      probs_list << [first_rand.round(2), second_rand.round(2)]
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
    list << Node.new(2, list[1])
    list << Node.new(3, list[1])
    list << Node.new(4, list[2])
    list << Node.new(5, list[1])
    list << Node.new(6, list[3])
    list << Node.new(7, list[2])
    list << Node.new(8, list[4])
    list << Node.new(9, list[5])
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
