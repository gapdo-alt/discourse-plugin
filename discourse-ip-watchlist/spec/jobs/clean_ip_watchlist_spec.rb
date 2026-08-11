# frozen_string_literal: true

RSpec.describe Jobs::CleanIpWatchlist do
  before do
    enable_current_plugin
    SiteSetting.ip_watchlist_enabled = true
  end

  it "deletes stale watchlist entries outside retention but keeps enforced IPs" do
    SiteSetting.ip_watchlist_retention_days = 30

    stale =
      IpWatchlistEntry.upsert_hit!(ip_address: "203.0.113.1", reason: "manual")
    stale.update!(last_seen_at: 60.days.ago, first_seen_at: 60.days.ago)

    kept =
      IpWatchlistEntry.upsert_hit!(ip_address: "203.0.113.2", reason: "manual")
    kept.update!(last_seen_at: 60.days.ago, first_seen_at: 60.days.ago)
    IpWatchlistEnforcement.create!(
      ip_address: "203.0.113.2",
      group_id: Fabricate(:group).id,
      enabled: true,
    )

    fresh =
      IpWatchlistEntry.upsert_hit!(ip_address: "203.0.113.3", reason: "manual")

    described_class.new.execute

    expect(IpWatchlistEntry.exists?(id: stale.id)).to eq(false)
    expect(IpWatchlistEntry.exists?(id: kept.id)).to eq(true)
    expect(IpWatchlistEntry.exists?(id: fresh.id)).to eq(true)
  end

  it "does nothing when retention days is 0" do
    SiteSetting.ip_watchlist_retention_days = 0
    entry =
      IpWatchlistEntry.upsert_hit!(ip_address: "203.0.113.4", reason: "manual")
    entry.update!(last_seen_at: 400.days.ago, first_seen_at: 400.days.ago)

    described_class.new.execute
    expect(IpWatchlistEntry.exists?(id: entry.id)).to eq(true)
  end
end
