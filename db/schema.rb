ActiveRecord::Schema.define do
  create_table :curated_articles, if_not_exists: true do |t|
    t.string :title, null: false
    t.text :description
    t.string :url, null: false
    t.string :source_name
    t.datetime :published_at
    t.datetime :curated_at, null: false
    t.text :curation_reason
    t.integer :relevance_score
    t.string :category
    t.timestamps
  end

  add_index :curated_articles, :url, unique: true, if_not_exists: true
  add_index :curated_articles, :curated_at, if_not_exists: true
  add_index :curated_articles, :published_at, if_not_exists: true

  create_table :user_feedback, if_not_exists: true do |t|
    t.integer :curated_article_id, null: false
    t.boolean :liked
    t.text :notes
    t.datetime :feedback_at, null: false
    t.timestamps
  end

  add_index :user_feedback, :curated_article_id, if_not_exists: true
  add_index :user_feedback, :liked, if_not_exists: true

  create_table :user_preferences, if_not_exists: true do |t|
    t.string :key, null: false
    t.text :value
    t.timestamps
  end

  add_index :user_preferences, :key, unique: true, if_not_exists: true

  create_table :curation_sessions, if_not_exists: true do |t|
    t.datetime :session_date, null: false
    t.integer :articles_fetched
    t.integer :articles_curated
    t.text :agent_notes
    t.timestamps
  end

  add_index :curation_sessions, :session_date, unique: true, if_not_exists: true
end
