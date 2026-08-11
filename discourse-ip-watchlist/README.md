# Discourse IP Watchlist

观察登录 IP，确认后再晋升为群组入组规则。

## 功能

1. **观察库（自动）**
   - 使用 Discourse 内置 MaxMind（`DiscourseIpInfo`）读取组织名 / 主机名
   - 组织名或主机名命中可配置关键词 → 写入观察库
   - HTTP Referer 命中通配符（如 `*114.114.114.114*`）→ 写入观察库
   - 管理员可手动添加精确 IP

2. **入组规则（管理员晋升）**
   - 观察一段时间后，可将 IP 晋升并指定一个或多个群组
   - 晋升时：该 IP 上全部历史账号立刻入组
   - 之后从该 IP 登录的用户也会加入对应群组（只加不删）

3. **IP 组**
   - 自定义命名的 IP 组（如「华为云可疑」「办公室出口」）
   - 每个 IP 组可关联一个或多个 Discourse 群组
   - 将 IP 加入 IP 组后，该 IP 的历史及新登录用户自动加入关联群组
   - 在管理员用户详情页显示该 IP 所属组 / 同网段提示，并可一键加入 IP 组
     （注：Discourse 核心的 IP 查询弹窗无插件注入点，按钮在用户管理页详情区域，不在弹窗内部）

4. **其它**
   - 仅管理员可访问
   - 观察记录可配置保留天数（已晋升 IP 不会被自动清理）
   - 观察库提供「同 IP 用户」管理链接

## 安装

本插件位于多插件仓库中。请按仓库根目录 [README](../README.md) 的软链方式部署，例如：

```yml
hooks:
  after_code:
    - exec:
        cd: $home
        cmd:
          - rm -rf $home/discourse-plugins-mono
          - git clone https://github.com/gapdo-alt/discourse-plugin.git $home/discourse-plugins-mono
          - ln -sfn $home/discourse-plugins-mono/discourse-ip-watchlist $home/plugins/discourse-ip-watchlist
```

重建容器后，在 **管理 → 插件 → IP Watchlist** 中启用并配置。

## 配置项

| 设置 | 说明 |
|------|------|
| `ip_watchlist_enabled` | 总开关 |
| `ip_watchlist_org_keywords` | 组织名关键词（子串，忽略大小写） |
| `ip_watchlist_hostname_keywords` | 主机名关键词 |
| `ip_watchlist_referrer_patterns` | Referrer 通配，`*` 为任意字符 |
| `ip_watchlist_retention_days` | 观察库保留天数，`0` 表示不自动清理 |

默认组织关键词包含 `huawei` / `hw cloud` / `HUAWEI CLOUDS`；默认主机名关键词包含 `hwclouds-dns`。

### Referrer 示例

公司风险提示页跳转论坛时，Referer 类似：

`http://114.114.114.114:8080/...`

可配置：

`*114.114.114.114*`

## 管理页

路径：`/admin/plugins/discourse-ip-watchlist/ip-watchlist`

- **观察库**：搜索、手动添加、删除、晋升入组、查看同 IP 用户
- **入组规则**：直接添加、启用/停用、删除

## 开发测试

在 Discourse 开发环境中：

```bash
LOAD_PLUGINS=1 bin/rspec plugins/discourse-ip-watchlist/spec
```

（需先将本目录软链到 Discourse 的 `plugins/discourse-ip-watchlist`。）
