require 'ai/command/base'
require 'graphviz'
require 'byebug'

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
      @k_fold = 5

      puts "ML"

      artificial_data
    end
  end

  def artificial_data
    classes = []
    dep_tree = DependenceTree.new(gen_dep_list)

    @num_classes.times.with_index do |i|
      probs_list = gen_dependence_probabilities(dep_tree)
      samples = gen_samples(i, @num_samples, probs_list, dep_tree)
      est_ind_probs = est_feature_probabilities(samples)
      est_cond_probs = est_cond_probs_matrix(samples)
      cond_diffs = ind_cond_diff_matrix(est_ind_probs, est_cond_probs)
      ord_cond_diffs = ordered_cond_diffs(cond_diffs)
      est_dep_tree = est_dep_tree(ord_cond_diffs)
      est_dep_probs = est_dep_probs(est_dep_tree, est_cond_probs, est_ind_probs)
      classes << {probs: probs_list, samples: samples,
        est_ind_probs: est_ind_probs,
        est_cond_probs: est_cond_probs,
        cond_diffs: cond_diffs,
        ord_cond_diffs: ord_cond_diffs,
        est_dep_tree: est_dep_tree,
        est_dep_probs: est_dep_probs
      }
    end
    puts "probs"
    puts classes[0][:probs].to_s
    puts "est_ind_probs"
    puts classes[0][:est_ind_probs].to_s
    puts "est_dep_probs"
    puts classes[0][:est_dep_probs].to_s
    puts "est_cond_probs"
    puts classes[0][:est_cond_probs][1]
    puts "cond_diffs"
    puts classes[0][:cond_diffs][1]

    sample_set = []
    classes.each do |classs|
      sample_set += classs[:samples]
    end

    conf_matrix_ind_bayes = ind_bayes_classification(sample_set)
    conf_matrix_dep_bayes = dep_bayes_classification(classes[0][:est_dep_tree], sample_set)

    dec_tree = gen_dec_tree(sample_set, classes)
    conf_matrix_dec_tree = dec_tree_classification(dec_tree, sample_set)

    byebug
    # dep_tree.output_graph
  end

  def dec_tree_classification(dec_tree, sample_set)
    all_samples = sample_set.shuffle
    matrix = initialize_conf_matrix
    classes = Array.new(@num_classes) {|i| Hash.new}
    test_size = all_samples.count / @k_fold

    i = 0
    @k_fold.times do
      test_samples = all_samples[(test_size*i)...(test_size*(i+1))]
      train_samples = all_samples[0...(test_size*i)]
      train_samples += all_samples[(test_size*(i+1))...all_samples.count]

      test_samples.each do |test_sample|
        predicted = classify_sample_dec_tree(test_sample, dec_tree)
        actual = test_sample.last
        matrix[:"#{actual}_#{predicted}"] += 1
      end
      i += 1
    end
    matrix
  end

  def classify_sample_dec_tree(test_sample, dec_tree)
    node = dec_tree.root
    while node.children.any?
      node = node.children[test_sample[node.feature]]
    end
    node.class
  end

  def gen_dec_tree(sample_set, classes)
    current_samples = sample_set.shuffle
    remaining_features = FEATURE_LIST.to_a
    klasses = classes.map {|c| {probs: c[:est_ind_probs]}}
    dec_tree_list = []
    gen_dec_tree_list_rec(nil, nil, current_samples, remaining_features, dec_tree_list, klasses)

    DecisionTree.new(dec_tree_list)
  end

  def gen_dec_tree_list_rec(parent, outcome, samples, remaining, dec_tree_list, klasses)
    return if samples.empty?
    class_counts = class_counts(samples)
    if class_counts.max == samples.count || remaining.empty?
      klass = if class_counts.max == samples.count
        samples[0].last
      elsif class_counts.count(class_counts.max) == 1
        class_counts.index(class_counts.max)
      else
        classify_sample_ind(klasses, samples[0])
      end
      node = Node.new(nil, parent, {outcome: outcome, class: klass})
      dec_tree_list << node
      return
    end
    best = best_info_gain_attr(remaining, samples)
    node = Node.new(best, parent, {outcome: outcome})
    dec_tree_list << node
    pos_samples = samples.select {|s| s[best] == 0}
    neg_samples = samples.select {|s| s[best] == 1}
    remaining = remaining - [best]
    gen_dec_tree_list_rec(node, 0, pos_samples, remaining, dec_tree_list, klasses)
    gen_dec_tree_list_rec(node, 1, neg_samples, remaining, dec_tree_list, klasses)
  end

  def best_info_gain_attr(feature_list, samples)
    max_gain_feature = -1
    max_entropy = -1
    feature_list.each do |feature|
      current_entropy = entropy_for_samples(samples)
      pos_samples = samples.select {|s| s[feature] == 0}
      neg_samples = samples.select {|s| s[feature] == 1}
      entropy_reduction = pos_samples.count/samples.count.to_f * entropy_for_samples(pos_samples)
                        + neg_samples.count/samples.count.to_f * entropy_for_samples(neg_samples)
      new_entropy = current_entropy - entropy_reduction
      if new_entropy > max_entropy
        max_entropy = new_entropy
        max_gain_feature = feature
      end
    end
    return max_gain_feature
  end

  def dep_bayes_classification(dep_tree, sample_set)
    all_samples = sample_set.shuffle
    matrix = initialize_conf_matrix
    classes = Array.new(@num_classes) {|i| Hash.new}
    test_size = all_samples.count / @k_fold

    i = 0
    @k_fold.times do
      test_samples = all_samples[(test_size*i)...(test_size*(i+1))]
      train_samples = all_samples[0...(test_size*i)]
      train_samples += all_samples[(test_size*(i+1))...all_samples.count]

      classes.each_with_index do |classs, index|
        class_samples = train_samples.select {|s| s.last == index}
        classs[:probs] = est_dep_probs(dep_tree,
          est_cond_probs_matrix(class_samples),
          est_feature_probabilities(class_samples))
      end

      test_samples.each do |test_sample|
        predicted = classify_sample_dep(classes, test_sample, dep_tree)
        actual = test_sample.last
        matrix[:"#{actual}_#{predicted}"] += 1
      end
      i += 1
    end
    matrix
  end

  def classify_sample_dep(classes, test_sample, dep_tree)
    llhs = []
    classes.each do |classs|
      node = dep_tree.root
      llh = classs[:probs][node.feature]
      node.children.each do |child|
        llh = llh * classify_sample_dep_rec(test_sample, child, classs[:probs])
      end
      llhs << llh
    end
    llhs.index(llhs.max)
  rescue
    byebug
  end

  def classify_sample_dep_rec(sample, node, probs_list)
    parent_feature = sample[node.parent.feature]
    llh = 1
    node.children.each do |child|
      llh = llh * classify_sample_dep_rec(sample, child, probs_list)
    end
    prob = probs_list[node.feature][parent_feature]
    chance = sample[node.feature] == 0 ? prob : 1 - prob
    return llh * chance
  end

  # perform naive bayes classification
  def ind_bayes_classification(sample_set)
    all_samples = sample_set.shuffle
    matrix = initialize_conf_matrix
    classes = Array.new(@num_classes) {|i| Hash.new}
    test_size = all_samples.count / @k_fold

    i = 0
    @k_fold.times do
      test_samples = all_samples[(test_size*i)...(test_size*(i+1))]
      train_samples = all_samples[0...(test_size*i)]
      train_samples += all_samples[(test_size*(i+1))...all_samples.count]

      classes.each_with_index do |classs, index|
        class_samples = train_samples.select {|s| s.last == index}
        classs[:probs] = est_feature_probabilities(class_samples)
      end

      test_samples.each do |test_sample|
        predicted = classify_sample_ind(classes, test_sample)
        actual = test_sample.last
        matrix[:"#{actual}_#{predicted}"] += 1
      end
      i += 1
    end
    matrix
  end

  # classify sample by treating features independently
  def classify_sample_ind(classes, sample)
    llh = []
    classes.each do |classs|
      likelihood = 1
      classs[:probs].zip(sample).each do |prob, feature|
        chance = feature == 0 ? prob : 1 - prob
        likelihood = likelihood * chance
      end
      llh << likelihood
    end
    llh.index(llh.max)
  rescue
    byebug
  end

  # Estimate the dependent probabilities based on the estimated tree
  def est_dep_probs(est_dep_tree, est_cond_probs, est_ind_probs)
    dep_probs = []
    est_dep_tree.list.each do |node|
      dep_prob = if node.parent
        est_cond_probs[node.feature][:"#{node.parent.feature}"]
      else
        est_ind_probs[node.feature]
      end
      dep_probs.insert(node.feature, dep_prob)
    end
    dep_probs
  end

  # build tree from order of weighted edge diffs
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
  def est_cond_probs_matrix(samples)
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

  def entropy_for_samples(samples)
    class_counts = class_counts(samples)
    entropy(class_counts)
  end

  def entropy(class_sample_count)
    base = class_sample_count.count
    total = class_sample_count.sum
    entropy = 0
    class_sample_count.each do |class_count|
      next if class_count == 0
      class_fraction = (class_count/total.to_f)
      entropy += -class_fraction * Math.log(class_fraction, base)
    end
    entropy
  end

  def class_counts(samples)
    counts = []
    @num_classes.times do |i|
      counts << samples.count {|s| s.last == i}
    end
    counts
  end

  def initialize_conf_matrix
    matrix = {}
    i = 0
    @num_classes.times do
      j = 0
      @num_classes.times do
        matrix[:"#{i}_#{j}"] = 0
        j += 1
      end
      i += 1
    end
    matrix
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
      self
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

  class DecisionTree < DependenceTree

    def populate_children
      list.each do |node|
        children = []
        list.each do |child|
          if child.parent && child.parent == node
            children.insert(child.outcome, child)
          end
        end
        node.children = children
      end
      self
    end

    def output_graph
      g = GraphViz.new( :G, :type => :digraph )
      glist = []

      # Create nodes
      list.each_with_index do |node,i|
        glist << g.add_nodes(node.feature.to_s+"(#{i})")
      end

      # Create edges between the nodes
      list.each_with_index do |node|
        if node.parent
          g.add_edges(glist[list.index(node.parent)], glist[list.index(node)])
        end
      end

      # Generate output image
      g.output( :png => "dependence_tree.png" )
    end
  end

  class Node

    attr_accessor :feature, :parent, :children, :outcome, :class

    def initialize(feature, parent, opts={})
      @feature = feature
      @parent = parent
      @outcome = opts[:outcome]
      @class = opts[:class]
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
