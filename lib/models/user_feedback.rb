require 'active_record'

class UserFeedback < ActiveRecord::Base
  self.table_name = 'user_feedback'
  belongs_to :curated_article, class_name: 'CuratedArticle', foreign_key: 'curated_article_id'

  validates :curated_article_id, :feedback_at, presence: true
  validates :liked, inclusion: { in: [true, false] }

  scope :recent, -> { order(feedback_at: :desc) }
  scope :positive, -> { where(liked: true) }
  scope :negative, -> { where(liked: false) }
end
