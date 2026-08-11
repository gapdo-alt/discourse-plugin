# Discourse 插件仓库（多插件）

本仓库包含多个独立 Discourse 插件，每个子目录是一个完整插件：

| 目录 | 插件名 | 说明 |
|------|--------|------|
| [`discourse-ip-watchlist/`](discourse-ip-watchlist/) | discourse-ip-watchlist | IP 观察库与入组规则 |
| [`snowball/`](snowball/) | snowball | 占位插件（待实现） |

## 部署（Docker / app.yml）

Discourse 只加载 `plugins/<目录>/plugin.rb`。多插件仓库需要 clone 后软链到 `plugins/`：

```yml
hooks:
  after_code:
    - exec:
        cd: $home
        cmd:
          - rm -rf /tmp/discourse-plugins-mono
          - git clone https://github.com/gapdo-alt/discourse-plugin.git /tmp/discourse-plugins-mono
          - ln -sfn /tmp/discourse-plugins-mono/discourse-ip-watchlist $home/plugins/discourse-ip-watchlist
          - ln -sfn /tmp/discourse-plugins-mono/snowball $home/plugins/snowball
```

若需指定分支：

```yml
- git clone -b cursor/ip-group-membership-b098 https://github.com/gapdo-alt/discourse-plugin.git /tmp/discourse-plugins-mono
```

然后重建：

```bash
cd /var/discourse
./launcher rebuild app
```

在 **管理 → 插件** 中分别启用各插件。

## 本地开发

```bash
# 在 Discourse 源码的 plugins 下软链
ln -s /path/to/discourse-plugin/discourse-ip-watchlist plugins/discourse-ip-watchlist
ln -s /path/to/discourse-plugin/snowball plugins/snowball
```

## 新增插件

1. 在仓库根目录新建文件夹（建议与 `# name:` 一致）
2. 放入完整插件结构（至少包含 `plugin.rb`）
3. 在 `app.yml` 增加对应 `ln -sfn` 行
4. 更新本 README 的插件列表
