require 'active_record'

class CuratedArticle < ActiveRecord::Base
  self.table_name = 'curated_articles'
  has_many :user_feedback, class_name: 'UserFeedback', foreign_key: 'curated_article_id', dependent: :destroy

  validates :title, :url, :curated_at, presence: true
  validates :url, uniqueness: true

  scope :recent, -> { order(curated_at: :desc) }
  scope :today, -> { where('DATE(curated_at) = ?', Date.today) }
  scope :liked, -> { joins(:user_feedback).where(user_feedback: { liked: true }) }
  scope :disliked, -> { joins(:user_feedback).where(user_feedback: { liked: false }) }

  def feedback
    user_feedback.first
  end

  def liked?
    feedback&.liked == true
  end

  def disliked?
    feedback&.liked == false
  end

  def formatted_date
    curated_at.strftime('%Y-%m-%d %H:%M')
  end
end
