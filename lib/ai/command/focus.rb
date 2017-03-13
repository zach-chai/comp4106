require 'ai/command/base'
require 'byebug'
require 'deep_clone'

class AI::Command::Focus < AI::Command::Base
  VALID_METHODS = ['help']
  DEFAULT_SIZE = 8
  DEFAULT_PLAYERS = 2
  DEFAULT_DEPTH = 0
  DEFAULT_SLEEP = 0
  SMALL_SIZE = 4
  PLAYER_ONE = 1
  PLAYER_TWO = 2
  PLAYER_THREE = 3
  PLAYER_FOUR = 4
  EMPTY_SPACE = []
  NULL_SPACE = nil
  INPUT_SEPARATOR = '.'
  LETTERS = ('a'..'h').to_a

  def index
    if @opts.help?
      $stdout.puts slop_opts
    else
      @size = DEFAULT_SIZE
      @num_players = @opts[:players].to_i
      @depth = @opts[:depth].to_i
      @sleep = @opts[:sleep].to_i
      @debug = @opts[:debug]
      @human = @opts[:interactive]

      @players = [PLAYER_ONE, PLAYER_TWO]
      @players << PLAYER_THREE if @num_players > 2
      @players << PLAYER_FOUR if @num_players > 3

      board = State.new(@size)
      if @num_players == 2
        board.populate2
      elsif @num_players == 4
        board.populate4
      end

      # board.move('1.b6.b5', PLAYER_ONE)
      # board.move('2.b5.b4', PLAYER_ONE)
      # board.move('3.b4.b3', PLAYER_ONE)
      # board.move('4.b3.b2', PLAYER_ONE)
      # board.move('1.c1.c2', PLAYER_ONE)
      # board.move('2.c2.c3', PLAYER_ONE)
      # board.move('3.c3.c4', PLAYER_ONE)
      # board.move('4.c4.c5', PLAYER_ONE)
      # board.move('1.f1.f0', PLAYER_ONE)
      # board.move('1.f6.f7', PLAYER_TWO)
      board.print_state
      @node = Node.new(board, nil)

      start_computer_game
    end
  end

  def human_move
    input = nil
    while true
      puts 'Enter a move'
      input = $stdin.gets
      unless @node.state.move(input.chomp, PLAYER_ONE)
        puts 'Invalid move'
        next
      end
      break
    end
  end

  def start_computer_game
    while true
      if @players.count(PLAYER_ONE) > 0
        if @human
          human_move
        else
          @node = find_best(@node, PLAYER_ONE)
        end
        update_view
      end
      if @players.count(PLAYER_TWO) > 0
        @node = find_best(@node, PLAYER_TWO)
        update_view
      end
      if @players.count(PLAYER_THREE) > 0
        @node = find_best(@node, PLAYER_THREE)
        update_view
      end
      if @players.count(PLAYER_FOUR) > 0
        @node = find_best(@node, PLAYER_FOUR)
        update_view
      end
      if @players.count == 1
        break
      end
    end
    puts "Player #{@players[0]} won!"
  end

  def update_view
    @node.state.print_state
    if @sleep
      sleep @sleep
    end
    if @debug
      byebug
    end
  end

  def find_best(node, player)
    transitions = valid_transitions(node, player)
    if transitions.empty?
      @players.delete(player)
      return node
    end
    transitions.map! do |trans|
      {node: trans, value: alphabeta(trans, @depth, player, player, -9999, 9999)}
    end
    max = (transitions.map {|t| t[:value]}).max
    transitions.select! {|t| t[:value] == max}
    transitions.sample[:node]
  end

  def alphabeta(node, depth, player_perspective, max_player, alpha, beta)
    if depth == 0
      if max_player == PLAYER_ONE || max_player == PLAYER_FOUR
        return heuristic1(node.state, max_player)
      else
        return heuristic2(node.state, max_player)
      end
    end
    transitions = valid_transitions(node, player_perspective)
    if transitions.empty?
      if max_player == PLAYER_ONE || max_player == PLAYER_FOUR
        return heuristic1(node.state, max_player)
      else
        return heuristic2(node.state, max_player)
      end
    end
    next_player = @players[(@players.index(player_perspective) + 1) % @players.count]

    if player_perspective == max_player
      value = -9999
      transitions.each do |child|
        value = [alphabeta(child, depth - 1, next_player, max_player, alpha, beta), value].max
        alpha = [alpha, value].max
        if beta <= alpha
          break
        end
      end
      return value
    else
      value = 9999
      transitions.each do |child|
        value = [alphabeta(child, depth - 1, next_player, max_player, alpha, beta), value].min
        beta = [beta, value].min
        if beta <= alpha
          break
        end
      end
      return value
    end
  end

  def heuristic1(state, player)
    control(state, player) + captured(state, player) + moveable(state, player) * 2
  end

  def heuristic2(state, player)
    control(state, player) + captured(state, player) * 2
  end

  # maximize yours stacks try to have to most biggest stacks
  def control(state, player)
    player_info = state.send(:"player#{player}")
    count = 0
    board = state.board
    board.each_with_index do |row, r|
      row.each_with_index do |stack, s|
        if stack && stack[0] == player
          count += stack.size
        end
      end
    end
    count
  end

  # maximizes the number of moveable stacks (stacks with your piece at the top)
  def moveable(state, player)
    count = 0
    board = state.board
    board.each_with_index do |row, r|
      row.each_with_index do |stack, s|
        if stack && stack[0] == player
          count += 1
        end
      end
    end
    count
  end

  # maximize the number of captured pieces
  def captured(state, player)
    player_info = state.send(:"player#{player}")[:captured]
  end

  def valid_transitions(current_node, player)
    state = current_node.state
    transitions = []
    state.board.each_with_index do |row, r_coord|
      valid_letters = if row.size == 4
        LETTERS[2...6]
      elsif row.size == 6
        LETTERS[1...7]
      else
        LETTERS
      end
      valid_letters.each_with_index do |letter, c_coord|
        stack = state.stack_at_position(Position.new({string: "#{letter}#{r_coord}"}))
        if stack && stack[0] == player
          # byebug
          num_pieces = 1
          stack.size.times do
            # byebug
            modifier = 1
            num_pieces.times do
              input = "#{num_pieces}.#{letter}#{r_coord}.#{letter}#{r_coord+modifier}"
              if state.move(input, player, true)
                transitions << Node.new(state.deep_clone.move(input, player), nil)
              end
              modifier += 1
            end
            modifier = 1
            num_pieces.times do
              input = "#{num_pieces}.#{letter}#{r_coord}.#{letter}#{r_coord-modifier}"
              if state.move(input, player, true)
                transitions << Node.new(state.deep_clone.move(input, player), nil)
              end
              modifier += 1
            end
            modifier = 1
            num_pieces.times do
              input = "#{num_pieces}.#{letter}#{r_coord}.#{LETTERS[LETTERS.index(letter)+modifier]}#{r_coord}"
              if state.move(input, player, true)
                transitions << Node.new(state.deep_clone.move(input, player), nil)
              end
              modifier += 1
            end
            modifier = 1
            num_pieces.times do
              input = "#{num_pieces}.#{letter}#{r_coord}.#{LETTERS[LETTERS.index(letter)-modifier]}#{r_coord}"
              if state.move(input, player, true)
                transitions << Node.new(state.deep_clone.move(input, player), nil)
              end
              modifier += 1
            end
            num_pieces += 1
          end
        end
        input = "#{letter}#{r_coord}"
        if state.place(input, player, true)
          transitions << Node.new(state.deep_clone.move(input, player), nil)
        end
      end
    end
    transitions
  end

  class Node

    attr_accessor :state, :parent

    def initialize(state, parent)
      @state = state
      @parent = parent
    end
  end

  class State

    attr_accessor :board, :size, :player1, :player2, :player3, :player4

    def initialize(size)
      @size = size
      size2 = size-2
      size4 = size-4

      @board = Array.new(size/2)
      @board.map! do |arr|
        Array.new(size, EMPTY_SPACE)
      end
      @board.unshift(Array.new(size2, EMPTY_SPACE)) if size2 > 0
      @board.unshift(Array.new(size4, EMPTY_SPACE)) if size4 > 0

      @board.push(Array.new(size2, EMPTY_SPACE)) if size2 > 0
      @board.push(Array.new(size4, EMPTY_SPACE)) if size4 > 0

      @player1 = {pieces: 0, captured: 0}
      @player2 = {pieces: 0, captured: 0}
      @player3 = {pieces: 0, captured: 0}
      @player4 = {pieces: 0, captured: 0}
    end

    # input - 1.b2.b3 | b5
    def move(input, player_id, verify_only=false)
      input = input.split(INPUT_SEPARATOR)
      if input.size == 1
        return place(input[0], player_id)
      end
      size = input[0].to_i
      src = Position.new({string: input[1]}) rescue nil
      dest = Position.new({string: input[2]}) rescue nil

      unless verify_move(size, src, dest, player_id)
        return false
      end
      if verify_only
        return true
      end

      src_stack = stack_at_position(src)
      move_stack = src_stack[0...size]
      remain_stack = src_stack[size...src_stack.size]
      dest_stack = stack_at_position(dest)

      removed_stack = (move_stack + dest_stack)
      new_stack = removed_stack.shift(5)

      player_info = self.send(:"player#{player_id}")
      player_info[:pieces] += removed_stack.count(player_id)
      player_info[:captured] += removed_stack.size - removed_stack.count(player_id)

      set_position(dest, new_stack)
      set_position(src, remain_stack)
      self
    end

    def place(input, player_id, verify_only=false)
      dest = Position.new({string: input}) rescue nil

      unless verify_place(dest, player_id)
        return false
      end
      if verify_only
        return true
      end

      dest_stack = stack_at_position(dest)

      removed_stack = ([player_id] + dest_stack)
      new_stack = removed_stack.shift(5)

      player_info = self.send(:"player#{player_id}")
      player_info[:pieces] += removed_stack.count(player_id) - 1
      player_info[:captured] += removed_stack.size - removed_stack.count(player_id)

      set_position(dest, new_stack)
      self
    end

    def verify_place(dest, player)

      # verify pieces available to be placed
      if self.send(:"player#{player}")[:pieces] <= 0
        return false
      end

      # verify input is within board spec
      if dest.column > 7 || dest.row > 7
        return false
      elsif dest.column < 0 || dest.row < 0
        return false
      elsif stack_at_position(dest).nil?
        return false
      end

      true
    end

    def verify_move(size, src, dest, player)

      # nil check
      if !src || !dest || !size || !player
        return false
      end

      # cannot move stack to its occupying square
      if src.eql(dest)
        return false
      end

      # verify input is within board spec
      if size > 5 || size < 1
        return false
      elsif src.column >= 8 || src.row > 7 || dest.column >= 8 || dest.row > 7
        return false
      elsif src.column < 0 || src.row < 0 || dest.column < 0 || dest.row < 0
        return false
      elsif stack_at_position(src).nil? || stack_at_position(dest).nil?
        return false
      end

      # verify enough pieces to move exist
      if stack_at_position(src).size < size
        return false
      end

      # verify moves are not diagonal
      if src.row != dest.row && src.column != dest.column
        return false
      end

      # verify distance within number of pieces moved
      dist = (src.row + src.column - dest.row - dest.column).abs
      if dist > size
        return false
      end

      # verify player owns top piece on stack
      if stack_at_position(src)[0] != player
        return false
      end

      true
    end

    def populate2
      if size == DEFAULT_SIZE
        @board.map!.with_index do |arr, y|
          if y == 0 || y == DEFAULT_SIZE - 1
            arr
          else
            count = 0
            player = (y % 2 == 0) ? PLAYER_TWO : PLAYER_ONE
            arr.map!.with_index do |space, x|
              if arr.size == DEFAULT_SIZE && (x == 0 || x == DEFAULT_SIZE - 1)
                EMPTY_SPACE
              else
                if count > 1 && count % 2 == 0
                  player = if player == PLAYER_ONE
                    PLAYER_TWO
                  else
                    PLAYER_ONE
                  end
                end
                count += 1
                [player]
              end
            end
          end
        end
      end
    end

    def populate4
      @board = []
      @board << [[PLAYER_ONE], [PLAYER_ONE], [PLAYER_TWO], [PLAYER_THREE]]
      @board << [[PLAYER_THREE], [PLAYER_THREE], [PLAYER_THREE], [PLAYER_TWO], [PLAYER_THREE]]
      @board << [[PLAYER_ONE], [PLAYER_ONE], [PLAYER_ONE], [PLAYER_ONE], [PLAYER_TWO], [PLAYER_THREE], [PLAYER_TWO]]
      @board << [[PLAYER_THREE], [PLAYER_THREE], [PLAYER_THREE], [PLAYER_THREE], [PLAYER_TWO], [PLAYER_THREE], [PLAYER_TWO], [PLAYER_THREE]]
      @board << [[PLAYER_FOUR], [PLAYER_ONE], [PLAYER_FOUR], [PLAYER_ONE], [PLAYER_FOUR], [PLAYER_FOUR], [PLAYER_FOUR], [PLAYER_FOUR]]
      @board << [[PLAYER_FOUR], [PLAYER_ONE], [PLAYER_FOUR], [PLAYER_ONE], [PLAYER_TWO], [PLAYER_TWO], [PLAYER_TWO], [PLAYER_TWO]]
      @board << [[PLAYER_ONE], [PLAYER_FOUR], [PLAYER_ONE], [PLAYER_FOUR], [PLAYER_FOUR], [PLAYER_FOUR]]
      @board << [[PLAYER_FOUR], [PLAYER_ONE], [PLAYER_TWO], [PLAYER_TWO]]
      @board
    end

    # def populate_test
    #   @board = []
    #   @board << [[],[],[],[]]
    #   @board << [[1],[],[],[],[],[]]
    #   @board << [[],[],[],[],[],[],[],[]]
    #   @board << [[],[],[],[],[],[],[],[]]
    #   @board << [[],[],[],[],[],[],[],[]]
    #   @board << [[],[],[],[],[],[],[],[]]
    #   @board << [[],[],[],[],[],[]]
    #   @board << [[],[],[],[]]
    #   @board
    # end

    def print_state
      spacing = "%15s "
      printf " %15s %15s %15s %15s %15s %15s %15s %15s\n", *(('A'..'H').to_a)
      num = 0

      board.each_with_index do |row, i|
        formatting = ""
        print num
        num += 1

        extra = (size - row.size) / 2
        edges = []
        extra.times do
          edges.push(nil)
        end

        columns = row.size + extra
        columns.times do
          formatting += spacing
        end
        formatting += "\n"
        printf formatting, *(edges + row)
      end

      4.times do |player|
        num = PLAYER_ONE + player
        player_info = self.send(:"player#{num}")
        puts "Player#{num} pieces: #{player_info[:pieces]}, captured: #{player_info[:captured]}"
      end
    end

    def stack_at_position(pos)
      row = pos.row
      column = pos.column
      reduce = 0
      if row == 0 || row == 7
        reduce = 2
      elsif row == 1 || row == 6
        reduce = 1
      end
      if column - reduce >= 0
        if board.nil? || board[row].nil?
          byebug
        end
        board[row][column - reduce]
      else
        nil
      end
    end

    def set_position(pos, value)
      row = pos.row
      column = pos.column
      reduce = 0
      if row == 0 || row == 7
        reduce = 2
      elsif row == 1 || row == 6
        reduce = 1
      end
      if column - reduce < 0
        raise "position out of bounds"
      end
      board[row][column - reduce] = value
    end

    def letter_to_num(letter)
      LETTERS.index(letter.downcase)
    end

    def deep_clone
      DeepClone.clone(self)
    end
  end

  class Position
    LETTERS = ('a'..'h').to_a

    attr_accessor :row, :column

    def initialize(opts = {})
      @column = letter_to_num(opts[:string][0])
      @row = opts[:string][1].to_i
      if !@column || !@row || opts[:string].length > 2
        raise "invalid Position spec"
      end
    end

    def eql(pos)
      self.row == pos.row && self.column == pos.column
    end

    def letter_to_num(letter)
      LETTERS.index(letter.downcase)
    end
  end

  private

  def self.setup_options
    opts = Slop::Options.new
    opts.banner = 'Usage: ai smp [options]'
    opts.separator ''
    opts.separator 'Smp options:'
    opts.bool '-h', '--help', 'print options', default: false
    opts.string '-p', '--players', 'number of players 2|4', default: DEFAULT_PLAYERS.to_s
    opts.string '-d', '--depth', 'depth 1|2', default: DEFAULT_DEPTH.to_s
    opts.string '-s', '--sleep', 'sleep time in seconds', DEFAULT_SLEEP.to_s
    opts.bool '-b', '--debug', 'debug mode', default: false
    opts.bool '-i', '--interactive', 'interactive mode', default: false


    self.slop_opts = opts
    self.parser = Slop::Parser.new(opts)
  end

  setup_options
end
