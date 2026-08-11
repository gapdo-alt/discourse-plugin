# Discourse Plugins

Gap.do Discourse 插件集合。

| 目录 | 说明 |
|------|------|
| [`snowball/`](./snowball/) | Snowball 员工姓氏验证插件 |

## 快速安装 Snowball

在 Discourse 服务器上：

```bash
cd /var/discourse
git clone --depth 1 https://github.com/gapdo-alt/discourse-plugin.git /tmp/discourse-plugin
cp -r /tmp/discourse-plugin/snowball containers/app/plugins/discourse-snowball
rm -rf /tmp/discourse-plugin
./launcher rebuild app
```

详见 [`snowball/README.md`](./snowball/README.md)。
