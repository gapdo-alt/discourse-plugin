# Discourse 插件仓库（多插件）

本仓库包含多个独立 Discourse 插件，每个子目录是一个完整插件：

| 目录 | 插件名 | 说明 |
|------|--------|------|
| [`discourse-ip-watchlist/`](discourse-ip-watchlist/) | discourse-ip-watchlist | IP 观察库与入组规则 |
| [`snowball/`](snowball/) | snowball | 占位插件（待实现） |

## 部署（Docker / app.yml）

**不要**克隆到 `/tmp`（重建后可能丢失，导致软链断裂、站点 Oops）。  
推荐：克隆到 `$home`，再用 `cp -a` 拷贝进 `plugins/`。

在 `containers/app.yml` 的 `hooks.after_code` 中配置：

```yml
hooks:
  after_code:
    - exec:
        cd: $home
        cmd:
          - git clone https://github.com/discourse/docker_manager.git $home/plugins/docker_manager
          - rm -rf $home/discourse-plugins-mono
          - git clone -b cursor/ip-group-membership-b098 https://github.com/gapdo-alt/discourse-plugin.git $home/discourse-plugins-mono
          - rm -rf $home/plugins/discourse-ip-watchlist $home/plugins/snowball
          - cp -a $home/discourse-plugins-mono/discourse-ip-watchlist $home/plugins/discourse-ip-watchlist
          - cp -a $home/discourse-plugins-mono/snowball $home/plugins/snowball
```

说明：

- 若原 `cmd` 里已有 `docker_manager` 那一行，不要重复添加，只加插件相关几行。
- 仓库若仍是 **Private**，匿名 clone 会失败（exit 128）：请改为 Public，或在 URL 中加 token：`https://<TOKEN>@github.com/gapdo-alt/discourse-plugin.git`
- 合并到 `main` 后可去掉 `-b cursor/ip-group-membership-b098`

然后：

```bash
cd /var/discourse
./launcher rebuild app
```

在 **管理 → 插件** 中分别启用各插件。

## 本地 Docker 测试

在本地用 Docker 跑完整 Discourse 实例测试插件：

```bash
bash scripts/setup-local-discourse.sh
```

详见 [`scripts/README-LOCAL-TEST.md`](scripts/README-LOCAL-TEST.md)。

- 访问：http://localhost:8080
- 插件 UI：http://localhost:8080/admin/plugins/ip-watchlist
- 嵌套 Docker 环境（如 Cloud Agent）会自动切换存储驱动并加 `--skip-prereqs`

## 本地开发（Discourse 源码目录）

```bash
ln -s /path/to/discourse-plugin/discourse-ip-watchlist plugins/discourse-ip-watchlist
ln -s /path/to/discourse-plugin/snowball plugins/snowball
```

## 新增插件

1. 在仓库根目录新建文件夹（建议与 `# name:` 一致）
2. 放入完整插件结构（至少包含 `plugin.rb`）
3. 在 `app.yml` 增加对应 `cp -a` 行
4. 更新本 README 的插件列表
