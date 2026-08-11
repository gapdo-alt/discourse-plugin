# frozen_string_literal: true

# Snowball API 客户端：探测工号邻域权重（±1000）、通过判定、防刷等均由远端 API 计算。
require "json"
require "net/http"
require "uri"

module SnowballApi
  class Error < StandardError
    attr_reader :status, :body

    def initialize(message, status: 500, body: nil)
      super(message)
      @status = status
      @body = body
    end
  end

  class Response
    attr_reader :status, :body, :set_cookie

    def initialize(status:, body:, set_cookie: nil)
      @status = status
      @body = body
      @set_cookie = set_cookie
    end

    def json
      @json ||= JSON.parse(body)
    end
  end

  module_function

  def base_url
    url = SiteSetting.snowball_api_url.to_s.strip
    raise Error.new("snowball_api_url 未配置", status: 503) if url.empty?

    url.delete_suffix("/")
  end

  def challenge(username:, client_ip:, cookies: nil)
    request(
      :post,
      "/api/challenge",
      body: { username: username },
      client_ip: client_ip,
      cookies: cookies,
    )
  end

  def verify(challenge_id:, username:, answers:, client_ip:, cookies: nil)
    request(
      :post,
      "/api/verify",
      body: {
        challenge_id: challenge_id,
        username: username,
        answers: answers,
      },
      client_ip: client_ip,
      cookies: cookies,
    )
  end

  def status(username:)
    uri = URI("#{base_url}/api/status?#{URI.encode_www_form(username: username)}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 15

    res = http.get(uri.request_uri)
    Response.new(status: res.code.to_i, body: res.body)
  rescue StandardError => e
    raise Error.new("Snowball API 请求失败: #{e.message}", status: 502)
  end

  def request(method, path, body: nil, client_ip: nil, cookies: nil)
    uri = URI("#{base_url}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 20

    req =
      case method
      when :post
        Net::HTTP::Post.new(uri)
      when :get
        Net::HTTP::Get.new(uri)
      else
        raise ArgumentError, "unsupported method #{method}"
      end

    req["Content-Type"] = "application/json"
    req["Accept"] = "application/json"
    req["X-Forwarded-For"] = client_ip if client_ip.present?
    req["Cookie"] = cookies if cookies.present?
    req.body = body.to_json if body

    res = http.request(req)
    set_cookie = res.get_fields("set-cookie")&.first

    Response.new(status: res.code.to_i, body: res.body, set_cookie: set_cookie)
  rescue StandardError => e
    raise Error.new("Snowball API 请求失败: #{e.message}", status: 502)
  end
end
