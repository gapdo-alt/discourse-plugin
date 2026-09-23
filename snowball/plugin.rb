# frozen_string_literal: true

# name: discourse-snowball
# about: Snowball 员工姓氏验证 — 使用本地种子库（后台 JSON 导入），验证通过后加群并提升信任等级
# version: 0.2.0
# authors: Gap.do
# url: https://github.com/gapdo-alt/discourse-plugin/tree/main/snowball
# required_version: 3.0.0

enabled_site_setting :snowball_enabled

# Only stylesheets may be registered manually.  Everything under
# assets/javascripts (including .js and .gjs) is picked up automatically by
# Discourse's plugin asset pipeline -- calling register_asset on it raises
# a RuntimeError and prevents the whole application from booting.
register_asset "stylesheets/common/snowball.scss"

# The label is translated as-is inside the admin bundle, so it must be a full
# admin_js key (a bare "snowball.title" would fall back to "Plugins").
add_admin_route "admin.plugins.snowball.title", "snowball", use_new_show_route: true

module ::Snowball
  PLUGIN_NAME = "discourse-snowball"
end

after_initialize do
  # Discourse does not autoload a plugin's app/ directory (only plugins that
  # define a Rails::Engine get that for free), so classes under app/ must be
  # required explicitly -- otherwise the controller cannot be resolved and
  # every /snowball/* route answers 404.
  require_relative "app/models/snowball_seed"
  require_relative "app/models/snowball_observation"
  require_relative "app/models/snowball_resigned_observation"
  require_relative "app/models/snowball_verification_attempt"
  require_relative "app/models/snowball_challenge"
  require_relative "app/controllers/snowball_controller"
  require_relative "app/controllers/snowball/admin_controller"
  require_relative "app/jobs/scheduled/snowball_expire_verifications"
  require_relative "lib/snowball_limits"
  require_relative "lib/snowball_promoter"
  require_relative "lib/snowball_seed_import"
  require_relative "lib/snowball_verifier"
end

Discourse::Application.routes.append do
  # The Ember route lives at /snowball, so the server must serve the app shell
  # for that path as well -- otherwise a direct visit or a page reload 404s
  # (client-side navigation alone would work, but deep links would not).
  get "/snowball" => "snowball#index"
  post "/snowball/challenge" => "snowball#challenge"
  post "/snowball/verify" => "snowball#verify"
  get "/snowball/status" => "snowball#status"

  # Admin: seed library import / inspection
  get "/admin/snowball/seeds" => "snowball/admin#seeds", :constraints => AdminConstraint.new
  post "/admin/snowball/seeds" => "snowball/admin#import", :constraints => AdminConstraint.new
  delete "/admin/snowball/seeds" => "snowball/admin#destroy_all", :constraints => AdminConstraint.new
end
