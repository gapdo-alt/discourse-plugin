# frozen_string_literal: true

# name: discourse-snowball
# about: Snowball 员工姓氏验证 — 对接 Cloudflare Snowball API，验证通过后加群并提升信任等级
# version: 0.1.0
# authors: Gap.do
# url: https://github.com/gapdo-alt/discourse-plugin/tree/main/snowball
# required_version: 3.0.0

enabled_site_setting :snowball_enabled

# Only stylesheets may be registered manually.  Everything under
# assets/javascripts (including .js and .hbs) is picked up automatically by
# Discourse's plugin asset pipeline -- calling register_asset on it raises
# a RuntimeError and prevents the whole application from booting.
register_asset "stylesheets/common/snowball.scss"

after_initialize do
  # Discourse does not autoload a plugin's app/ directory (only plugins that
  # define a Rails::Engine get that for free), so classes under app/ must be
  # required explicitly -- otherwise the controller cannot be resolved and
  # every /snowball/* route answers 404.
  require_relative "app/models/snowball_verification_attempt"
  require_relative "app/controllers/snowball_controller"
  require_relative "app/jobs/scheduled/snowball_expire_verifications"
  require_relative "lib/snowball_api"
  require_relative "lib/snowball_limits"
  require_relative "lib/snowball_promoter"
end

Discourse::Application.routes.append do
  # The Ember route lives at /snowball, so the server must serve the app shell
  # for that path as well -- otherwise a direct visit or a page reload 404s
  # (client-side navigation alone would work, but deep links would not).
  get "/snowball" => "snowball#index"
  post "/snowball/challenge" => "snowball#challenge"
  post "/snowball/verify" => "snowball#verify"
  get "/snowball/status" => "snowball#status"
end
