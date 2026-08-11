# Discourse Snowball 集成插件

将 [Snowball 员工验证 API](https://snowball-verify.pages.dev) 接入 Discourse 论坛。用户完成姓氏验证后，自动加入指定群组并提升信任等级。

## 功能

- 站内页面 `/snowball`：5 分钟倒计时、5 道工号题
- 服务端代理 Snowball API（转发用户 IP 与 `sb_uid` Cookie，防刷规则生效）
- 验证通过后：加入群组 + 提升信任等级 + 写入用户自定义字段 `snowball_verified_at`
- 导航菜单入口（可关闭）

## 安装

### 方式一：放入 Discourse 容器 plugins 目录

```bash
cd /var/discourse
git clone --depth 1 https://github.com/gapdo-alt/discourse-plugin.git /tmp/discourse-plugin
cp -r /tmp/discourse-plugin/snowball containers/app/plugins/discourse-snowball
rm -rf /tmp/discourse-plugin
./launcher rebuild app
```

### 方式二：app.yml 挂载

在 `containers/app.yml` 的 `hooks:after_code` 中加入：

```yaml
- exec:
    cd: $home/plugins
    cmd:
      - rm -rf discourse-snowball
      - git clone --depth 1 https://github.com/gapdo-alt/discourse-plugin.git /tmp/discourse-plugin
      - cp -r /tmp/discourse-plugin/snowball discourse-snowball
      - rm -rf /tmp/discourse-plugin
```

然后 `./launcher rebuild app`。

## 站点设置

在 **管理 → 设置 → 插件** 中配置：

| 设置项 | 说明 | 默认值 |
|--------|------|--------|
| `snowball_enabled` | 启用插件 | `true` |
| `snowball_api_url` | Snowball API 根地址 | `https://snowball-verify.pages.dev` |
| `snowball_verified_group` | 验证后加入的群组名 | `verified-employees` |
| `snowball_trust_level` | 验证后信任等级（0=不调整） | `2` |
| `snowball_show_nav_link` | 显示导航入口 | `true` |

**部署前请先在 Discourse 创建群组**（如 `verified-employees`）。

## API 代理说明

插件在 Discourse 服务端转发以下请求到 Snowball：

| Discourse 路由 | Snowball API | 说明 |
|----------------|--------------|------|
| `POST /snowball/challenge` | `POST /api/challenge` | 使用当前登录用户名 |
| `POST /snowball/verify` | `POST /api/verify` | 通过后执行加群/升 TL |
| `GET /snowball/status` | `GET /api/status` | 查询验证状态 |

请求会附带 `X-Forwarded-For: <用户 IP>`，与 Snowball 防刷指纹逻辑兼容。

## 用户流程

1. 登录用户打开 `/snowball` 或点击导航「员工验证」
2. 点击「开始验证」→ 根据工号填写正确姓氏（复姓填首字，英文名填首字母）
3. 填写姓氏或勾选「已离职」→ 提交
4. 通过：Snowball 记录验证 + Discourse 加群/升 TL

## 验证规则（服务端，不在用户页展示）

出题、通过判定与探测权重由 Snowball API 统一计算，详见 [API 文档](https://snowball-verify.pages.dev/docs.html)。

## 目录结构

```
snowball/
  plugin.rb
  config/settings.yml
  lib/snowball_api.rb
  lib/snowball_promoter.rb
  app/controllers/snowball_controller.rb
  assets/javascripts/discourse/...
  assets/stylesheets/common/snowball.scss
  locales/
```

## 故障排查

- **创建挑战失败**：检查 `snowball_api_url` 是否可访问
- **验证通过但未加群**：确认群组名称存在，且 API 用户有管理权限
- **防刷限制**：每周 3 次，无间隔冷却

## 相关链接

- Snowball API 文档：https://snowball-verify.pages.dev/docs.html
- 插件仓库：https://github.com/gapdo-alt/discourse-plugin
- Snowball 工程（gongka）：https://github.com/gapdo-alt/gongka/tree/main/document/snowball
