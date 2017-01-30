# require 'ai/command/base'

class AI::Command::Ctp < AI::Command::Base
  VALID_METHODS = ['help']

  def index
    if @opts.help?
      $stdout.puts slop_opts
    else
      puts "in ctp"
    end
  end

  private

  def self.setup_options
    opts = Slop::Options.new
    opts.banner = 'Usage: ai ctp [options]'
    opts.separator ''
    opts.bool '-h', '--help', 'print options', default: false
    # opts.separator 'Ctp options:'
    # opts.string '-o', '--output', 'output filename', default: DEFAULT_OUT_FILE
    # opts.string '-d', '--directory', 'root directory to generate', default: DEFAULT_DIRECTORY
    # opts.bool '-m', '--minify', 'minify JSON output', default: false

    self.slop_opts = opts
    self.parser = Slop::Parser.new(opts)
  end

  setup_options
end
