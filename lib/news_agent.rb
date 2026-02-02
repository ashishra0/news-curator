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
    prefs = context[:preferences]
    user_profile = prefs['user_profile'] || {}
    learning_approach = prefs['learning_approach'] || {}
    content_prefs = prefs['content_preferences'] || {}

    # Extract key settings
    knowledge_level = user_profile['knowledge_level'] || 'intermediate'
    article_complexity = user_profile['article_complexity'] || 'analytical'
    reading_time = user_profile['reading_time_minutes'] || '15-20'
    learning_goals = user_profile['learning_goals'] || []

    context_needs = learning_approach['context_needs'] || 'moderate'
    terminology_learning = learning_approach['terminology_learning'] || 'contextual'
    cognitive_load = learning_approach['cognitive_load'] || 'moderate_challenge'

    coverage_style = content_prefs['coverage_style'] || 'diverse_topics'
    source_perspective = content_prefs['source_perspective'] || 'balanced'
    geographic_focus = content_prefs['geographic_focus'] || []
    avoid_duplicates = content_prefs['avoid_duplicate_stories'] || false

    knowledge_instructions = case knowledge_level
    when 'beginner'
      "USER IS A BEGINNER - CRITICAL REQUIREMENTS:\n" \
      "- Prioritize articles that explain concepts clearly for general audiences\n" \
      "- Avoid articles with heavy jargon or assumed specialized knowledge\n" \
      "- Select articles that provide background context and explain key players/terms\n" \
      "- Look for explainer pieces, analysis for non-experts, and well-structured narratives"
    when 'advanced'
      "USER IS ADVANCED - Select articles with deep analysis, specialized terminology, and nuanced diplomatic insights."
    when 'expert'
      "USER IS AN EXPERT - Prioritize technical analysis, policy papers, and sophisticated diplomatic commentary."
    else
      "USER IS INTERMEDIATE - Balance accessibility with analytical depth."
    end

    complexity_instructions = case article_complexity
    when 'accessible_journalism'
      "ARTICLE COMPLEXITY: Select clear, straightforward journalism. Avoid academic papers or dense policy analysis."
    when 'academic'
      "ARTICLE COMPLEXITY: Prefer academic depth, research papers, and technical policy analysis."
    else
      "ARTICLE COMPLEXITY: Balance accessible and analytical content."
    end

    coverage_instructions = case coverage_style
    when 'diverse_topics'
      "COVERAGE STYLE: Select #{target_count} articles on DIFFERENT topics/stories. Maximum topic diversity required."
    when 'deep_focus'
      "COVERAGE STYLE: Can select multiple articles on the same major story if it's significant."
    else
      "COVERAGE STYLE: Usually diverse topics, but allow multiple articles on truly major developments."
    end

    duplicate_instructions = avoid_duplicates ?
      "CRITICAL: NEVER select multiple articles covering the same event/story. Each article must be about a completely different topic." :
      "Multiple articles on the same story are acceptable if they provide different perspectives."

    terminology_instructions = case terminology_learning
    when 'in_article_explanations'
      "TERMINOLOGY: Strongly prefer articles that define diplomatic terms and explain concepts within the text."
    when 'glossary'
      "TERMINOLOGY: Articles can use specialized terms; they'll be explained separately."
    else
      "TERMINOLOGY: Standard diplomatic terminology is acceptable."
    end

    context_instructions = case context_needs
    when 'progressive'
      "CONTEXT: Provide articles with good background context now. Over time, as user builds knowledge, less context will be needed."
    when 'extensive'
      "CONTEXT: Require articles with extensive historical background and explanations."
    when 'minimal'
      "CONTEXT: Focus on current developments; assume user can research background independently."
    else
      "CONTEXT: Brief context on major developments is sufficient."
    end

    source_instructions = case source_perspective
    when 'international'
      "SOURCE PERSPECTIVE: Strongly prefer international sources (non-Indian publications) to understand global viewpoints on India and regional issues."
    when 'indian'
      "SOURCE PERSPECTIVE: Prefer Indian sources explaining India's perspective and interests."
    else
      "SOURCE PERSPECTIVE: Mix of Indian and international sources for balanced views."
    end

    geo_instructions = if geographic_focus.empty?
      "GEOGRAPHIC FOCUS: General foreign policy and diplomacy coverage."
    else
      "GEOGRAPHIC FOCUS: Prioritize articles covering: #{geographic_focus.join(', ')}"
    end

    goals_context = if learning_goals.empty?
      ""
    else
      "\nUSER LEARNING GOALS: #{learning_goals.join(', ')} - select articles that support these objectives."
    end

    <<~PROMPT
      You are an intelligent news curator specializing in foreign policy and diplomacy.

      USER PROFILE:
      #{knowledge_instructions}

      Reading time available: #{reading_time} minutes
      #{goals_context}

      SELECTION CRITERIA (in priority order):

      1. TOPIC DIVERSITY:
         #{coverage_instructions}
         #{duplicate_instructions}

      2. COMPLEXITY & ACCESSIBILITY:
         #{complexity_instructions}
         #{terminology_instructions}

      3. CONTEXT & BACKGROUND:
         #{context_instructions}

      4. GEOGRAPHIC RELEVANCE:
         #{geo_instructions}

      5. SOURCE SELECTION:
         #{source_instructions}

      6. CONTENT QUALITY:
         - Provide substantive analysis or significant news (not superficial coverage)
         - Are HIGHLY relevant to Indian foreign policy, India's role in global diplomacy, or major diplomatic developments
         - Avoid celebrity/entertainment angles, focus on policy substance

      LEARNING FROM FEEDBACK:
      Previously liked articles (follow these patterns):
      #{context[:liked_patterns].empty? ? 'No feedback yet' : JSON.pretty_generate(context[:liked_patterns])}

      Previously disliked articles (AVOID similar content):
      #{context[:disliked_patterns].empty? ? 'No feedback yet - but still avoid duplicates!' : JSON.pretty_generate(context[:disliked_patterns])}

      ARTICLES TO ANALYZE:
      #{format_articles_for_prompt(articles)}

      TASK:
      Select exactly #{target_count} articles that best match the criteria above. Each article must be on a DIFFERENT topic/story.

      RESPONSE FORMAT (return ONLY the JSON array, no other text):
      [
        {
          "article_index": <index from 0 to #{articles.size - 1}>,
          "relevance_score": <integer from 1-10>,
          "category": "<one of: 'Indian Foreign Policy', 'Global Diplomacy', 'Bilateral Relations', 'Geopolitical Analysis'>",
          "reason": "<2-3 sentences explaining why this article matches the user's profile and what they'll learn from it>"
        }
      ]
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
