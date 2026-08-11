# frozen_string_literal: true

module ::IpWatchlist
  module Wildcard
    module_function

    # Convert a simple glob pattern (only `*` wildcards) into a case-insensitive Regexp.
    def to_regexp(pattern)
      return nil if pattern.blank?

      escaped =
        pattern.to_s.strip.chars.map { |char| char == "*" ? ".*" : Regexp.escape(char) }.join
      Regexp.new("\\A#{escaped}\\z", Regexp::IGNORECASE)
    end

    def match?(value, patterns)
      return false if value.blank? || patterns.blank?

      Array(patterns).any? do |pattern|
        regexp = to_regexp(pattern)
        regexp && value.to_s.match?(regexp)
      end
    end

    def contains_keyword?(value, keywords)
      return false if value.blank? || keywords.blank?

      haystack = value.to_s.downcase
      Array(keywords).any? { |keyword| keyword.present? && haystack.include?(keyword.to_s.downcase) }
    end
  end
end
