# frozen_string_literal: true

# Prefer explicit app routes over mounting under /admin/plugins/:name
# (core admin plugin routes can shadow an Engine mounted there).
Discourse::Application.routes.append do
  get "/admin/ip-watchlist" => "ip_watchlist/admin#index",
      :constraints => AdminConstraint.new
  post "/admin/ip-watchlist/entries" => "ip_watchlist/admin#create_entry",
       :constraints => AdminConstraint.new
  delete "/admin/ip-watchlist/entries/:id" => "ip_watchlist/admin#destroy_entry",
         :constraints => AdminConstraint.new
  post "/admin/ip-watchlist/entries/:id/promote" => "ip_watchlist/admin#promote",
       :constraints => AdminConstraint.new

  get "/admin/ip-watchlist/enforcements" => "ip_watchlist/admin#enforcements",
      :constraints => AdminConstraint.new
  post "/admin/ip-watchlist/enforcements" => "ip_watchlist/admin#create_enforcement",
       :constraints => AdminConstraint.new
  put "/admin/ip-watchlist/enforcements/:id" => "ip_watchlist/admin#update_enforcement",
      :constraints => AdminConstraint.new
  delete "/admin/ip-watchlist/enforcements/:id" => "ip_watchlist/admin#destroy_enforcement",
         :constraints => AdminConstraint.new

  get "/admin/ip-watchlist/ip-groups" => "ip_watchlist/admin#ip_groups",
      :constraints => AdminConstraint.new
  post "/admin/ip-watchlist/ip-groups" => "ip_watchlist/admin#create_ip_group",
       :constraints => AdminConstraint.new
  put "/admin/ip-watchlist/ip-groups/:id" => "ip_watchlist/admin#update_ip_group",
      :constraints => AdminConstraint.new
  delete "/admin/ip-watchlist/ip-groups/:id" => "ip_watchlist/admin#destroy_ip_group",
         :constraints => AdminConstraint.new
  post "/admin/ip-watchlist/ip-groups/:id/add-ip" => "ip_watchlist/admin#add_ip_to_group",
       :constraints => AdminConstraint.new
  delete "/admin/ip-watchlist/ip-groups/:id/remove-ip" => "ip_watchlist/admin#remove_ip_from_group",
         :constraints => AdminConstraint.new

  get "/admin/ip-watchlist/ip-groups-for-ip" => "ip_watchlist/admin#ip_groups_for_ip",
      :constraints => AdminConstraint.new
  post "/admin/ip-watchlist/quick-add-ip" => "ip_watchlist/admin#quick_add_ip",
       :constraints => AdminConstraint.new
end
