# frozen_string_literal: true

RSpec.describe IpWatchlist::Wildcard do
  before { enable_current_plugin }

  describe ".match?" do
    it "matches referrer wildcards including host:port patterns" do
      patterns = ["*114.114.114.114*"]
      expect(
        described_class.match?("http://114.114.114.114:8080/risk-warning", patterns),
      ).to eq(true)
      expect(described_class.match?("https://example.com/", patterns)).to eq(false)
    end

    it "is case-insensitive" do
      expect(described_class.match?("HTTP://Example.COM/x", ["http://example.com/*"])).to eq(true)
    end
  end

  describe ".contains_keyword?" do
    it "matches organization substrings case-insensitively" do
      expect(
        described_class.contains_keyword?("HUAWEI CLOUDS", ["hw cloud", "huawei"]),
      ).to eq(true)
      expect(described_class.contains_keyword?("Amazon.com", ["huawei"])).to eq(false)
    end
  end
end
