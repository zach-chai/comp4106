module AI
  module Command
    class << self
      attr_accessor :commands, :descriptions
    end

    @commands = []
    @descriptions = []

    def self.load
      Dir[File.join(File.dirname(__FILE__), "command", "*.rb")].each do |file|
        require file
        com = file.split('/')[-1].chomp('.rb')
        if com == 'base'
          next
        end
        self.commands << com
      end
    end

    def self.run(command, args)
      begin
        klass = "AI::Command::#{command.capitalize}"
        instance = Object.const_get(klass).new(args)
      rescue NameError
        $stdout.puts "ai: '#{command}' is not an ai command.\nSee 'ai --help' for usage."
        exit(1)
      end
      instance.execute
    end

    def commands
      self.class.commands
    end

  end
end
