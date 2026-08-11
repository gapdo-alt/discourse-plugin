# Discourse Plugins

Gap.do Discourse 插件集合。

| 目录 | 说明 |
|------|------|
| [`discourse-ip-watchlist/`](./discourse-ip-watchlist/) | IP 观察库与入组规则 |
| [`snowball/`](./snowball/) | Snowball 员工姓氏验证插件 |

## 安装方式（多插件仓库）

在 `containers/app.yml` 的 `hooks.after_code` 中：

```yml
hooks:
  after_code:
    - exec:
        cd: $home
        cmd:
          - git clone https://github.com/discourse/docker_manager.git
          - rm -rf $home/discourse-plugins-mono
          - git clone https://github.com/gapdo-alt/discourse-plugin.git $home/discourse-plugins-mono
          - rm -rf $home/plugins/discourse-ip-watchlist $home/plugins/snowball
          - cp -a $home/discourse-plugins-mono/discourse-ip-watchlist $home/plugins/discourse-ip-watchlist
          - cp -a $home/discourse-plugins-mono/snowball $home/plugins/snowball
```

然后：

```bash
cd /var/discourse
./launcher rebuild app
```

> 不要克隆到 `/tmp` 再用软链，重建后容易导致插件丢失或站点异常。

### 仅安装其中一个

```yml
# 只装 IP Watchlist
- git clone https://github.com/gapdo-alt/discourse-plugin.git $home/discourse-plugins-mono
- rm -rf $home/plugins/discourse-ip-watchlist
- cp -a $home/discourse-plugins-mono/discourse-ip-watchlist $home/plugins/discourse-ip-watchlist

# 只装 Snowball
- git clone https://github.com/gapdo-alt/discourse-plugin.git $home/discourse-plugins-mono
- rm -rf $home/plugins/snowball
- cp -a $home/discourse-plugins-mono/snowball $home/plugins/snowball
```

更多说明见各插件目录内 README。
