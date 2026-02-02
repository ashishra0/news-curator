require 'active_record'
require 'colorize'
require_relative 'news_fetcher'
require_relative 'news_agent'
require_relative 'models/curated_article'
require_relative 'models/curation_session'

class Curator
  def initialize
    @fetcher = NewsFetcher.new
    @agent = NewsAgent.new
  end

  def run_daily_curation
    puts "[INFO] Starting daily news curation...".colorize(:cyan)

    india_news = @fetcher.fetch_india_foreign_policy(max: 15)
    global_news = @fetcher.fetch_global_diplomacy(max: 15)

    all_articles = []
    if india_news[:success]
      all_articles += india_news[:articles]
      puts "[INFO] Fetched #{india_news[:count]} India articles".colorize(:green)
    else
      puts "[WARN] India news fetch failed: #{india_news[:error]}".colorize(:yellow)
    end

    if global_news[:success]
      all_articles += global_news[:articles]
      puts "[INFO] Fetched #{global_news[:count]} global articles".colorize(:green)
    else
      puts "[WARN] Global news fetch failed: #{global_news[:error]}".colorize(:yellow)
    end

    if all_articles.empty?
      puts "[ERROR] No articles fetched from any source".colorize(:red)
      return { success: false, error: 'Failed to fetch news from all sources' }
    end

    all_articles = remove_duplicates(all_articles)

    puts "[INFO] Fetched #{all_articles.size} unique articles".colorize(:yellow)

    target_count = UserPreference.get('articles_per_day') || 2

    puts "[INFO] Claude is analyzing articles...".colorize(:magenta)
    curated = @agent.curate_articles(all_articles, target_count: target_count)

    if curated.empty?
      puts "[WARN] No articles met the curation criteria".colorize(:yellow)
      return { success: false, error: 'No suitable articles found' }
    end

    saved_articles = save_articles(curated)

    session = CurationSession.create_session(
      articles_fetched: all_articles.size,
      articles_curated: saved_articles.size,
      agent_notes: "Selected #{saved_articles.size} articles with AI reasoning"
    )

    puts "[OK] Successfully curated #{saved_articles.size} articles!".colorize(:green)

    {
      success: true,
      articles: saved_articles,
      session: session
    }
  end

  def get_todays_articles
    CuratedArticle.today.recent
  end

  def provide_feedback(article_id, liked:, notes: nil)
    article = CuratedArticle.find(article_id)

    feedback = UserFeedback.create!(
      curated_article: article,
      liked: liked,
      notes: notes,
      feedback_at: Time.now
    )

    status = liked ? "[LIKED]" : "[DISLIKED]"
    puts "#{status} Feedback recorded! The agent will learn from this.".colorize(:green)
    feedback
  end

  private

  def remove_duplicates(articles)
    seen_urls = Set.new
    seen_titles = Set.new

    articles.select do |article|
      url = article['url']
      title = article['title']&.downcase&.strip

      next false if seen_urls.include?(url) || seen_titles.include?(title)

      seen_urls.add(url)
      seen_titles.add(title)
      true
    end
  end

  def save_articles(curated_selections)
    curated_selections.map do |selection|
      article_data = selection[:article]

      CuratedArticle.find_or_create_by(url: article_data['url']) do |article|
        article.title = article_data['title']
        article.description = article_data['description']
        article.source_name = article_data.dig('source', 'name')
        article.published_at = DateTime.parse(article_data['publishedAt']) rescue nil
        article.curated_at = Time.now
        article.curation_reason = selection[:reason]
        article.relevance_score = selection[:relevance_score]
        article.category = selection[:category]
      end
    end
  end
end
