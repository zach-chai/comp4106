# require 'cloudit/config'
require 'slop'

class AI::Command::Base
  class << self
    attr_accessor :parser, :slop_opts
  end

  def initialize(args=[])
    @method = if args[0].is_a?(String) && args[0].include?('-')
      nil
    else
      args.shift.strip rescue nil
    end
    @opts = parser.parse(args)
  end

  def execute
    puts @method

    if @method.nil?
      index
    elsif self.class::VALID_METHODS.include?(@method)
      self.send(@method)
    else
      invalid_method
    end
  end

  def invalid_method
    $stdout.puts "cloudit: '#{@method}' is not a cloudit command\nSee 'cloudit --help'"
  end

  def help
    $stdout.puts slop_opts
  end

  def parser
    self.class.parser
  end

  def slop_opts
    self.class.slop_opts
  end

end
