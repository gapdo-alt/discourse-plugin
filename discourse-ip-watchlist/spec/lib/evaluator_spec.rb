# frozen_string_literal: true

RSpec.describe IpWatchlist::Evaluator do
  fab!(:user)

  before do
    enable_current_plugin
    SiteSetting.ip_watchlist_enabled = true
    SiteSetting.ip_watchlist_org_keywords = "huawei|hw cloud"
    SiteSetting.ip_watchlist_hostname_keywords = "hwclouds-dns"
    SiteSetting.ip_watchlist_referrer_patterns = "*114.114.114.114*"
  end

  it "adds an IP to the watchlist when organization matches" do
    DiscourseIpInfo.stubs(:get).returns(
      organization: "HUAWEI CLOUDS",
      hostname: "other.example.com",
    )

    described_class.evaluate!(
      user_id: user.id,
      ip_address: "203.0.113.10",
      referrer: nil,
    )

    entry = IpWatchlistEntry.find_by(ip_address: "203.0.113.10")
    expect(entry).to be_present
    expect(entry.reason).to eq("org_keyword")
    expect(entry.organization).to eq("HUAWEI CLOUDS")
  end

  it "adds an IP to the watchlist when hostname matches" do
    DiscourseIpInfo.stubs(:get).returns(
      organization: "Other ASN",
      hostname: "ecs-1-2-3-4.compute.hwclouds-dns.com",
    )

    described_class.evaluate!(user_id: user.id, ip_address: "198.51.100.20")

    entry = IpWatchlistEntry.find_by(ip_address: "198.51.100.20")
    expect(entry.reason).to eq("hostname_keyword")
  end

  it "adds an IP to the watchlist when referrer matches" do
    DiscourseIpInfo.stubs(:get).returns(organization: "Other", hostname: "other.example")

    described_class.evaluate!(
      user_id: user.id,
      ip_address: "198.51.100.30",
      referrer: "http://114.114.114.114:8443/warn",
    )

    entry = IpWatchlistEntry.find_by(ip_address: "198.51.100.30")
    expect(entry.reason).to eq("referrer")
    expect(entry.referrer).to include("114.114.114.114")
  end

  it "assigns groups when an enforcement rule exists" do
    group = Fabricate(:group)
    IpWatchlistEnforcement.create!(
      ip_address: "203.0.113.55",
      group_id: group.id,
      enabled: true,
    )
    DiscourseIpInfo.stubs(:get).returns({})

    described_class.evaluate!(user_id: user.id, ip_address: "203.0.113.55")

    expect(group.users).to include(user)
  end
end
