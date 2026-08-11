# frozen_string_literal: true

# name: discourse-ip-watchlist
# about: Observe login IPs by ASN/hostname keywords and referrer wildcards, then promote them into group assignment rules.
# version: 0.1.0
# authors: Discourse Plugin
# url: https://github.com/discourse/discourse-ip-watchlist
# required_version: 3.2.0

enabled_site_setting :ip_watchlist_enabled

register_asset "stylesheets/ip-watchlist.scss"

add_admin_route "ip_watchlist.title", "ip-watchlist", use_new_show_route: true

module ::IpWatchlist
  PLUGIN_NAME = "discourse-ip-watchlist"
end

require_relative "lib/ip_watchlist/engine"
require_relative "lib/ip_watchlist/wildcard"
require_relative "lib/ip_watchlist/evaluator"
require_relative "lib/ip_watchlist/group_assigner"
require_relative "lib/ip_watchlist/application_controller_extension"

after_initialize do
  require_relative "app/models/ip_watchlist_entry"
  require_relative "app/models/ip_watchlist_enforcement"
  require_relative "app/serializers/ip_watchlist_entry_serializer"
  require_relative "app/serializers/ip_watchlist_enforcement_serializer"
  require_relative "app/controllers/ip_watchlist/admin_controller"
  require_relative "app/jobs/regular/evaluate_ip_watchlist"
  require_relative "app/jobs/scheduled/clean_ip_watchlist"

  IpWatchlist::Engine.routes.draw do
    get "/" => "admin#index"
    post "/entries" => "admin#create_entry"
    delete "/entries/:id" => "admin#destroy_entry"
    post "/entries/:id/promote" => "admin#promote"
    get "/enforcements" => "admin#enforcements"
    post "/enforcements" => "admin#create_enforcement"
    put "/enforcements/:id" => "admin#update_enforcement"
    delete "/enforcements/:id" => "admin#destroy_enforcement"
  end

  Discourse::Application.routes.append do
    mount ::IpWatchlist::Engine, at: "/admin/plugins/ip-watchlist"
  end

  # Capture Referer during the same request as login.
  reloadable_patch do
    ::ApplicationController.prepend(::IpWatchlist::ApplicationControllerExtension)
  end

  on(:user_logged_in) do |user|
    next unless SiteSetting.ip_watchlist_enabled
    next if user.blank? || user.ip_address.blank?

    Jobs.enqueue(
      :evaluate_ip_watchlist,
      user_id: user.id,
      ip_address: user.ip_address.to_s,
      referrer: RequestStore.store[:ip_watchlist_referrer],
    )
  end
end
