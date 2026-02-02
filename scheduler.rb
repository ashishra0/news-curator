#!/usr/bin/env ruby

require 'rufus-scheduler'
require 'dotenv/load'
require 'colorize'
require_relative 'lib/database'
require_relative 'lib/curator'
require_relative 'lib/models/curated_article'
require_relative 'lib/models/user_preference'
require_relative 'lib/models/user_feedback'
require_relative 'lib/models/curation_session'

Database.setup!

scheduler = Rufus::Scheduler.new

hour = ENV.fetch('CURATION_HOUR', '7').to_i
minute = ENV.fetch('CURATION_MINUTE', '0').to_i

puts "[SCHEDULER] News Curator Scheduler Starting...".colorize(:cyan)
puts "[SCHEDULER] Daily curation scheduled for #{hour}:#{sprintf('%02d', minute)} local time".colorize(:yellow)

scheduler.cron "#{minute} #{hour} * * *" do
  puts "\n[CRON] #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} - Running scheduled curation".colorize(:cyan)

  begin
    curator = Curator.new
    result = curator.run_daily_curation

    if result[:success]
      puts "[OK] Curation completed successfully".colorize(:green)
      puts "[INFO] Articles curated: #{result[:articles].size}".colorize(:green)
    else
      puts "[ERROR] Curation failed: #{result[:error]}".colorize(:red)
    end
  rescue StandardError => e
    puts "[ERROR] Error during curation: #{e.message}".colorize(:red)
    puts e.backtrace.join("\n").colorize(:red)
  end
end

puts "[INFO] Running initial curation...".colorize(:magenta)
begin
  curator = Curator.new
  result = curator.run_daily_curation
  puts "[OK] Initial curation completed".colorize(:green) if result[:success]
rescue StandardError => e
  puts "[WARN] Initial curation failed: #{e.message}".colorize(:yellow)
end

puts "\n[SCHEDULER] Scheduler is running. Press Ctrl+C to stop.".colorize(:green)

scheduler.join
