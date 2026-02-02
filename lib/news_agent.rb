require 'anthropic'
require 'json'
require_relative 'models/user_preference'
require_relative 'models/user_feedback'
require_relative 'models/curated_article'

class NewsAgent
  def initialize(api_key = nil)
    @api_key = api_key || ENV['ANTHROPIC_API_KEY']
    @client = Anthropic::Client.new(api_key: @api_key)
  end

  def curate_articles(articles, target_count: 2)
    return [] if articles.empty?

    context = build_context
    prompt = build_curation_prompt(articles, context, target_count)

    response = @client.messages.create(
      model: 'claude-sonnet-4-5-20250929',
      max_tokens: 4096,
      temperature: 0.3,
      messages: [
        { role: 'user', content: prompt }
      ]
    )

    content_text = response.content.first.text
    parse_curation_response(content_text, articles)
  end

  private

  def build_context
    preferences = UserPreference.all_preferences
    liked_articles = CuratedArticle.liked.recent.limit(10)
    disliked_articles = CuratedArticle.disliked.recent.limit(10)

    {
      preferences: preferences,
      liked_patterns: analyze_liked_articles(liked_articles),
      disliked_patterns: analyze_disliked_articles(disliked_articles)
    }
  end

  def analyze_liked_articles(articles)
    return [] if articles.empty?

    articles.map do |article|
      {
        title: article.title,
        reason: article.curation_reason,
        category: article.category
      }
    end
  end

  def analyze_disliked_articles(articles)
    return [] if articles.empty?

    articles.map do |article|
      {
        title: article.title,
        category: article.category
      }
    end
  end

  def build_curation_prompt(articles, context, target_count)
    <<~PROMPT
      You are an intelligent news curator specializing in foreign policy and diplomacy.

      USER PREFERENCES:
      #{JSON.pretty_generate(context[:preferences])}

      LEARNING FROM FEEDBACK:
      Previously liked articles (these are good examples):
      #{context[:liked_patterns].empty? ? 'No feedback yet' : JSON.pretty_generate(context[:liked_patterns])}

      Previously disliked articles (avoid similar content):
      #{context[:disliked_patterns].empty? ? 'No feedback yet' : JSON.pretty_generate(context[:disliked_patterns])}

      TASK:
      From the #{articles.size} articles below, select exactly #{target_count} articles that:
      1. Are HIGHLY relevant to Indian foreign policy, India's role in global diplomacy, or major diplomatic developments affecting India
      2. Provide substantive analysis or significant news (not superficial coverage)
      3. Match the user's preferences above
      4. Are different from previously disliked content
      5. Follow patterns similar to liked articles (if available)

      ARTICLES TO ANALYZE:
      #{format_articles_for_prompt(articles)}

      RESPONSE FORMAT:
      Return a JSON array with exactly #{target_count} selections. For each article:
      {
        "article_index": <index from 0 to #{articles.size - 1}>,
        "relevance_score": <integer from 1-10>,
        "category": "<one of: 'Indian Foreign Policy', 'Global Diplomacy', 'Bilateral Relations', 'Geopolitical Analysis'>",
        "reason": "<2-3 sentences explaining why this article is valuable and relevant>"
      }

      Return ONLY the JSON array, no other text.
    PROMPT
  end

  def format_articles_for_prompt(articles)
    articles.each_with_index.map do |article, idx|
      <<~ARTICLE
        [#{idx}] Title: #{article['title']}
        Source: #{article.dig('source', 'name')}
        Published: #{article['publishedAt']}
        Description: #{article['description']}
        ---
      ARTICLE
    end.join("\n")
  end

  def parse_curation_response(response_text, articles)
    json_match = response_text.match(/\[.*\]/m)
    return [] unless json_match

    selections = JSON.parse(json_match[0])

    selections.map do |selection|
      idx = selection['article_index']
      next unless idx && idx >= 0 && idx < articles.size

      article = articles[idx]
      {
        article: article,
        relevance_score: selection['relevance_score'],
        category: selection['category'],
        reason: selection['reason']
      }
    end.compact
  rescue JSON::ParserError => e
    puts "Error parsing Claude's response: #{e.message}"
    []
  end
end
