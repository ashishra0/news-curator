require 'active_record'
require 'json'

class UserPreference < ActiveRecord::Base
  self.table_name = 'user_preferences'
  validates :key, presence: true, uniqueness: true

  DEFAULTS = {
    'topics' => ['foreign policy', 'diplomacy', 'international relations'],
    'focus_areas' => [
      'Indian foreign policy',
      'India bilateral relations',
      'Global diplomacy',
      'Geopolitical shifts'
    ],
    'exclude_keywords' => ['bollywood', 'cricket', 'fashion', 'entertainment'],
    'min_relevance_score' => 7,
    'articles_per_day' => 2
  }.freeze

  class << self
    def get(key)
      pref = find_by(key: key.to_s)
      return parse_value(DEFAULTS[key.to_s]) unless pref
      parse_value(pref.value)
    end

    def set(key, value)
      pref = find_or_initialize_by(key: key.to_s)
      pref.value = serialize_value(value)
      pref.save!
      value
    end

    def all_preferences
      DEFAULTS.merge(
        all.each_with_object({}) do |pref, hash|
          hash[pref.key] = parse_value(pref.value)
        end
      )
    end

    private

    def parse_value(value)
      return value unless value.is_a?(String)
      begin
        JSON.parse(value)
      rescue JSON::ParserError
        value
      end
    end

    def serialize_value(value)
      value.is_a?(String) ? value : JSON.generate(value)
    end
  end
end
