require 'active_record'

class CurationSession < ActiveRecord::Base
  self.table_name = 'curation_sessions'
  validates :session_date, presence: true, uniqueness: true

  scope :recent, -> { order(session_date: :desc) }

  def self.today
    find_or_create_by(session_date: Date.today)
  end

  def self.create_session(articles_fetched:, articles_curated:, agent_notes: nil)
    create!(
      session_date: Date.today,
      articles_fetched: articles_fetched,
      articles_curated: articles_curated,
      agent_notes: agent_notes
    )
  end
end
