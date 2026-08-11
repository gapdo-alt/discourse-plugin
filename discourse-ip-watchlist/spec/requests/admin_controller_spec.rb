# frozen_string_literal: true

RSpec.describe IpWatchlist::AdminController do
  fab!(:admin)
  fab!(:group)
  fab!(:group2) { Fabricate(:group) }

  before do
    enable_current_plugin
    SiteSetting.ip_watchlist_enabled = true
    sign_in(admin)
  end

  describe "#index" do
    it "is admin-only" do
      sign_in(Fabricate(:user))
      get "/admin/ip-watchlist.json"
      expect([403, 404]).to include(response.status)
    end

    it "lists watchlist entries for admins" do
      IpWatchlistEntry.upsert_hit!(
        ip_address: "203.0.113.9",
        reason: "manual",
        organization: "HUAWEI CLOUDS",
      )

      get "/admin/ip-watchlist.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["entries"].first["ip_address"]).to eq("203.0.113.9")
      expect(response.parsed_body["entries"].first["same_ip_admin_url"]).to include(
        "ip=203.0.113.9",
      )
    end
  end

  describe "#promote" do
    it "creates enforcements for multiple groups and backfills users" do
      user = Fabricate(:user, ip_address: "198.51.100.9")
      entry =
        IpWatchlistEntry.upsert_hit!(ip_address: "198.51.100.9", reason: "org_keyword")

      post "/admin/ip-watchlist/entries/#{entry.id}/promote.json",
           params: {
             group_ids: [group.id, group2.id],
           }

      expect(response.status).to eq(200)
      expect(IpWatchlistEnforcement.where(ip_address: "198.51.100.9").count).to eq(2)
      expect(group.users).to include(user)
      expect(group2.users).to include(user)
    end
  end
end
