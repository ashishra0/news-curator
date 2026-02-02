#!/usr/bin/env ruby

require 'mcp'
require 'json'
require_relative 'lib/database'
require_relative 'lib/curator'
require_relative 'lib/models/curated_article'
require_relative 'lib/models/user_preference'

Database.setup!

class CurateNewsTool < MCP::Tool
  description "Get today's AI-curated news articles on foreign policy and diplomacy"
  input_schema(
    properties: {
      refresh: {
        type: "boolean",
        description: "Force a new curation (default: false, returns cached articles)"
      }
    }
  )

  class << self
    def call(refresh: false, server_context:)
      curator = Curator.new
      todays_articles = curator.get_todays_articles

      if refresh || todays_articles.empty?
        result = curator.run_daily_curation
        articles = result[:success] ? result[:articles] : []
      else
        articles = todays_articles
      end

      if articles.empty?
        text = "No curated articles available for today. Run curation manually with refresh: true"
      else
        text = format_articles(articles)
      end

      MCP::Tool::Response.new([{ type: "text", text: text }])
    end

    private

    def format_articles(articles)
      output = "Today's Curated News\n"
      output += "=" * 60 + "\n\n"

      articles.each_with_index do |article, idx|
        output += "#{idx + 1}. #{article.title}\n"
        output += "   Source: #{article.source_name} | #{article.formatted_date}\n"
        output += "   Relevance: #{article.relevance_score}/10 | #{article.category}\n"
        output += "   Why selected: #{article.curation_reason}\n"
        output += "   URL: #{article.url}\n"
        output += "   Article ID: #{article.id} (use this for feedback)\n"
        output += "\n" + "-" * 60 + "\n\n"
      end

      output += "Provide feedback using the news_feedback tool with the article ID\n"
      output
    end
  end
end

class NewsFeedbackTool < MCP::Tool
  description "Provide feedback (thumbs up/down) on a curated article to improve future recommendations"
  input_schema(
    properties: {
      article_id: {
        type: "integer",
        description: "ID of the article to provide feedback on"
      },
      liked: {
        type: "boolean",
        description: "true for thumbs up, false for thumbs down"
      },
      notes: {
        type: "string",
        description: "Optional notes about why you liked/disliked it"
      }
    },
    required: ["article_id", "liked"]
  )

  class << self
    def call(article_id:, liked:, notes: nil, server_context:)
      curator = Curator.new
      curator.provide_feedback(article_id, liked: liked, notes: notes)

      status = liked ? "LIKED" : "DISLIKED"
      text = "[#{status}] Feedback recorded! The AI will learn from your preferences."

      MCP::Tool::Response.new([{ type: "text", text: text }])
    rescue ActiveRecord::RecordNotFound
      MCP::Tool::Response.new(
        [{ type: "text", text: "[ERROR] Article not found with ID: #{article_id}" }],
        is_error: true
      )
    end
  end
end

class NewsPreferencesTool < MCP::Tool
  description "View or update your news curation preferences"
  input_schema(
    properties: {
      action: {
        type: "string",
        enum: ["view", "update"],
        description: "Action to perform: view current preferences or update them"
      },
      key: {
        type: "string",
        description: "Preference key to update (required for update action)"
      },
      value: {
        type: "string",
        description: "New value for the preference (required for update action, JSON string)"
      }
    },
    required: ["action"]
  )

  class << self
    def call(action:, key: nil, value: nil, server_context:)
      case action
      when "view"
        prefs = UserPreference.all_preferences
        text = "Your News Preferences:\n\n#{JSON.pretty_generate(prefs)}"
        MCP::Tool::Response.new([{ type: "text", text: text }])

      when "update"
        return MCP::Tool::Response.new(
          [{ type: "text", text: "[ERROR] Both key and value are required for update action" }],
          is_error: true
        ) unless key && value

        begin
          parsed_value = JSON.parse(value)
        rescue JSON::ParserError
          parsed_value = value
        end

        UserPreference.set(key, parsed_value)
        text = "[OK] Updated preference: #{key} = #{parsed_value.inspect}"
        MCP::Tool::Response.new([{ type: "text", text: text }])
      end
    end
  end
end

class NewsHistoryTool < MCP::Tool
  description "View history of curated articles and curation sessions"
  input_schema(
    properties: {
      days: {
        type: "integer",
        description: "Number of days to look back (default: 7)"
      }
    }
  )

  class << self
    def call(days: 7, server_context:)
      require_relative 'lib/models/curation_session'

      start_date = Date.today - days
      articles = CuratedArticle.where('curated_at >= ?', start_date).recent
      sessions = CurationSession.where('session_date >= ?', start_date).recent

      output = "Curation History (Last #{days} days)\n\n"
      output += "Total articles curated: #{articles.count}\n"
      output += "Curation sessions: #{sessions.count}\n\n"

      sessions.each do |session|
        output += "#{session.session_date}: "
        output += "#{session.articles_curated} articles from #{session.articles_fetched} fetched\n"
      end

      MCP::Tool::Response.new([{ type: "text", text: output }])
    end
  end
end

server = MCP::Server.new(
  name: "news-curator",
  version: "1.0.0",
  tools: [CurateNewsTool, NewsFeedbackTool, NewsPreferencesTool, NewsHistoryTool]
)

transport = MCP::Server::Transports::StdioTransport.new(server)

$stderr.puts "[MCP] News Curator MCP Server starting..."
$stderr.puts "[MCP] Server name: news-curator"
$stderr.puts "[MCP] Available tools: curate_news, news_feedback, news_preferences, news_history"

transport.open
