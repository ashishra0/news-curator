require 'active_record'
require 'yaml'
require 'dotenv/load'
require 'colorize'

module Database
  def self.connect(env = 'development')
    config = YAML.load_file(
      File.join(__dir__, '../config/database.yml'),
      aliases: true
    )[env]

    db_dir = File.dirname(config['database'])
    FileUtils.mkdir_p(db_dir) unless Dir.exist?(db_dir)

    ActiveRecord::Base.establish_connection(config)
    ActiveRecord::Base.logger = ENV['DEBUG'] ? Logger.new(STDOUT) : Logger.new(nil)
  end

  def self.migrate!
    schema_file = File.join(__dir__, '../db/schema.rb')
    if File.exist?(schema_file)
      # Silence ActiveRecord migration output for MCP
      old_stdout = $stdout
      $stdout = StringIO.new unless ENV['DEBUG']
      load(schema_file)
      $stdout = old_stdout unless ENV['DEBUG']
    end
  end

  def self.setup!
    connect
    migrate!
    $stderr.puts "[OK] Database connected and migrated" if ENV['DEBUG']
  end
end
