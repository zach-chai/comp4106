require 'ai/command'

module AI
  class CLI

    def self.start(*args)
      $stdin.sync = true if $stdin.isatty
      $stdout.sync = true if $stdout.isatty

      if args[0] && !args[0].include?('-')
        command = args.shift.strip rescue nil
      else
        nil
      end

      AI::Command.load
      AI::Command.run(command, args)
    end
  end
end
