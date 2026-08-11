# frozen_string_literal: true

RSpec.describe IpWatchlist::GroupAssigner do
  fab!(:user)
  fab!(:other_user) { Fabricate(:user) }
  fab!(:group)
  fab!(:group2) { Fabricate(:group) }

  let(:ip) { "203.0.113.77" }

  before do
    enable_current_plugin
    user.update!(ip_address: ip, registration_ip_address: ip)
    other_user.update!(ip_address: ip)
  end

  it "backfills all historical accounts for an IP into multiple groups" do
    described_class.backfill_ip!(ip_address: ip, group_ids: [group.id, group2.id])

    expect(group.users).to include(user, other_user)
    expect(group2.users).to include(user, other_user)
  end
end
