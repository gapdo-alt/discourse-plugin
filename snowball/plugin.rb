# frozen_string_literal: true

# name: discourse-snowball
# about: Snowball 员工姓氏验证 — 对接 Cloudflare Snowball API，验证通过后加群并提升信任等级
# version: 0.1.0
# authors: Gap.do
# url: https://github.com/gapdo-alt/discourse-plugin/tree/main/snowball
# required_version: 3.0.0

enabled_site_setting :snowball_enabled

register_asset "javascripts/discourse/helpers/format-employee-id.js"
register_asset "javascripts/discourse/helpers/format-employee-id-html.js"
register_asset "stylesheets/common/snowball.scss"
register_asset "javascripts/discourse/snowball-route-map.js"
register_asset "javascripts/discourse/controllers/snowball-verify.js"
register_asset "javascripts/discourse/routes/snowball-verify.js"
register_asset "javascripts/discourse/templates/snowball-verify.hbs"
register_asset "javascripts/discourse/initializers/snowball-nav.js"

after_initialize do
  require_relative "lib/snowball_api"
  require_relative "lib/snowball_promoter"
end

Discourse::Application.routes.append do
  post "/snowball/challenge" => "snowball#challenge"
  post "/snowball/verify" => "snowball#verify"
  get "/snowball/status" => "snowball#status"
end
