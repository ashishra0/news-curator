#!/usr/bin/env ruby

require 'fileutils'
require 'colorize'

puts "News Curator Setup".colorize(:cyan)
puts "=" * 10

puts "\n1. Checking Ruby version...".colorize(:yellow)
ruby_version = RUBY_VERSION.split('.').map(&:to_i)
if ruby_version[0] >= 3 && ruby_version[1] >= 2
  puts "   [OK] Ruby #{RUBY_VERSION} detected".colorize(:green)
else
  puts "   [ERROR] Ruby 3.2+ required. Current: #{RUBY_VERSION}".colorize(:red)
  exit 1
end

puts "\n2. Checking bundler...".colorize(:yellow)
unless system('which bundle > /dev/null 2>&1')
  puts "   Installing bundler...".colorize(:cyan)
  system('gem install bundler')
end
puts "   [OK] Bundler available".colorize(:green)

puts "\n3. Installing gems...".colorize(:yellow)
unless system('bundle install')
  puts "   [ERROR] Failed to install gems".colorize(:red)
  exit 1
end
puts "   [OK] Gems installed".colorize(:green)

puts "\n4. Setting up environment...".colorize(:yellow)
if File.exist?('.env')
  puts "   [WARN] .env already exists, skipping".colorize(:yellow)
else
  FileUtils.cp('.env.example', '.env')
  puts "   [OK] Created .env file".colorize(:green)
  puts "   [IMPORTANT] Edit .env and add your API keys!".colorize(:red).bold
end

puts "\n5. Creating directories...".colorize(:yellow)
['db', 'logs'].each do |dir|
  FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
end
puts "   [OK] Directories created".colorize(:green)

puts "\n6. Setting up database...".colorize(:yellow)
require_relative 'lib/database'
begin
  Database.setup!
  puts "   [OK] Database initialized".colorize(:green)
rescue => e
  puts "   [ERROR] Database setup failed: #{e.message}".colorize(:red)
  exit 1
end

puts "\n7. Setting default preferences...".colorize(:yellow)
require_relative 'lib/models/user_preference'
begin
  UserPreference.get('topics')
  UserPreference.get('focus_areas')
  puts "   [OK] Preferences initialized".colorize(:green)
rescue => e
  puts "   [ERROR] Failed to set preferences: #{e.message}".colorize(:red)
end

puts "\n8. Making scripts executable...".colorize(:yellow)
['bin/curate', 'scheduler.rb', 'mcp_server.rb'].each do |script|
  FileUtils.chmod(0755, script) if File.exist?(script)
end
puts "   [OK] Scripts are executable".colorize(:green)

puts "\n" + "=" * 50
puts "[OK] Setup Complete!".colorize(:green).bold
puts "\nNext Steps:".colorize(:cyan)
puts "   1. Edit .env and add your API keys:".colorize(:yellow)
puts "      - GNEWS_API_KEY from https://gnews.io/".colorize(:white)
puts "      - ANTHROPIC_API_KEY from https://console.anthropic.com/".colorize(:white)
puts "\n   2. Test the curation:".colorize(:yellow)
puts "      ./bin/curate --run".colorize(:white)
puts "\n   3. Start the scheduler (runs daily at 7 AM):".colorize(:yellow)
puts "      ruby scheduler.rb".colorize(:white)
puts "\n   4. Start the MCP server (for Claude Code):".colorize(:yellow)
puts "      ruby mcp_server.rb".colorize(:white)
puts "\nHappy curating!".colorize(:magenta)
