# 本地 Docker 测试 Discourse + discourse-ip-watchlist

## 一键安装

```bash
bash scripts/setup-local-discourse.sh
```

## 访问地址

| 用途 | URL |
|------|-----|
| 论坛首页 | http://localhost:8080 |
| 插件管理 UI | http://localhost:8080/admin/plugins/ip-watchlist |
| 插件 REST API | http://localhost:8080/admin/ip-watchlist.json |

## 管理员账号（测试用）

首次打开会进入安装向导；也可在容器内创建：

- 邮箱：`admin@example.com`
- 密码：`adminpass12345678`（Discourse 要求至少 15 位）

## 常用命令

在 `discourse-docker/` 目录下（嵌套 Docker 环境需加 `--skip-prereqs`）：

```bash
sudo ./launcher start app --skip-prereqs
sudo ./launcher stop app --skip-prereqs
sudo ./launcher rebuild app --skip-prereqs   # 改插件代码后
sudo ./launcher logs app
sudo ./launcher enter app
```

## 插件挂载

`discourse-ip-watchlist` 通过 volume 从本仓库挂载，改代码后执行 `rebuild app` 生效。

配置模板：`scripts/local-discourse-app.yml`

## Cloud Agent / 嵌套 Docker 说明

在 Cursor Cloud Agent 等**容器内跑 Docker** 的环境，默认 overlayfs 会因 whiteout 权限失败：

```
failed to convert whiteout file ... operation not permitted
```

`setup-local-discourse.sh` 会自动将 Docker 存储驱动改为 `native`（较慢但可用），并在 launcher 命令上加 `--skip-prereqs`。

首次 bootstrap 约 20–60 分钟（native 驱动会复制完整镜像层，占用约 40GB 磁盘）。

## 验证插件

```bash
# 创建 API Key（在容器内）
sudo docker exec -u discourse app bash -c \
  'cd /var/www/discourse && RAILS_ENV=production bundle exec rails runner \
  "puts ApiKey.create!(user_id: User.find_by(username: \"admin\").id, created_by_id: 1).key"'

# 测试 API（将 KEY 替换为上一步输出）
curl -H "Api-Key: KEY" -H "Api-Username: admin" -H "Accept: application/json" \
  http://127.0.0.1:8080/admin/ip-watchlist.json
```

预期返回 JSON，包含 `entries`、`enforcements`、`groups` 字段。
