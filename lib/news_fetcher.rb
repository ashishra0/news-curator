require 'httparty'
require 'dotenv/load'

class NewsFetcher
  include HTTParty
  base_uri 'https://gnews.io/api/v4'

  def initialize(api_key = nil)
    @api_key = api_key || ENV['GNEWS_API_KEY']
    raise 'GNEWS_API_KEY not set' unless @api_key
  end

  def fetch_news(query: nil, max: 20)
    query ||= build_query

    response = self.class.get('/search', query: {
      q: query,
      token: @api_key,
      lang: 'en',
      max: max,
      sortby: 'publishedAt'
    })

    handle_response(response)
  end

  def fetch_india_foreign_policy(max: 20)
    query = 'India (diplomacy OR "foreign policy" OR "external affairs" OR bilateral OR geopolitical)'
    fetch_news(query: query, max: max)
  end

  def fetch_global_diplomacy(max: 20)
    query = '(diplomacy OR "international relations" OR "foreign policy" OR geopolitical) -India'
    fetch_news(query: query, max: max)
  end

  private

  def build_query
    preferences = UserPreference.get('topics')
    topics = preferences.is_a?(Array) ? preferences : ['foreign policy', 'diplomacy']

    topics.map { |t| "\"#{t}\"" }.join(' OR ')
  end

  def handle_response(response)
    case response.code
    when 200
      articles = response.parsed_response['articles'] || []
      { success: true, articles: articles, count: articles.size }
    when 401
      { success: false, error: 'Invalid API key' }
    when 429
      { success: false, error: 'Rate limit exceeded' }
    else
      { success: false, error: "API error: #{response.code}" }
    end
  rescue StandardError => e
    { success: false, error: "Network error: #{e.message}" }
  end
end
