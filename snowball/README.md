# Discourse Snowball 集成插件

员工姓氏验证。**完全本地运行，不依赖任何外部服务**：种子库（工号 → 姓氏）由管理员在后台用 JSON 导入，出题、判定、权重调整全部在本插件内完成。

## 功能

- 站内页面 `/snowball`：5 分钟倒计时、题量可配置（默认 3 道种子题 + 2 道探测题，界面上不区分）
- **判定规则**：种子题答对数量达到「通过所需答对题数」即通过（默认 3 选 2）；答错的种子题置信度 **-3**
- **同号段出题**：一份验证里的工号取自同一个「区块」（默认 1000 号段，即只差后 3 位），方便按号段查名单；区块粒度可配
- **探测题反馈**：勾「已离职」→ 该工号及 **±1000** 邻域被抽中概率每票 **-5%**；填了姓氏 → 该工号进入观察库，±1000 邻域每锚点 **+5%**（上限 2.5×）
- 验证通过后：加入指定群组 + 提升信任等级 + 写入用户自定义字段 `snowball_verified_at`
- **次数限制**：每天 / 每周最多 N 次（默认 3/3，0 = 不限）。**提交答案才算一次**，开始验证不消耗
- **有效期**：默认 180 天。到期由每日任务（以及打开页面时的懒检查）自动移出验证群组并移入过期群组；**设为 0 = 永久有效**
- 后台管理页：导入 / 清空种子库、查看统计；可一键展开**种子库 / 观察库 / 离职库清单**（分页 + 按工号筛选）
- 导航菜单入口（可关闭）

**代码中不含任何种子数据**，库是空的，必须由管理员导入。

## 安装

在 `containers/app.yml` 的 `hooks:after_code` 中加入（**目录名必须是 `discourse-snowball`**，否则插件名与目录名不匹配）：

```yaml
- exec:
    cd: $home
    cmd:
      - rm -rf $home/discourse-plugins-mono
      - git clone https://github.com/gapdo-alt/discourse-plugin.git $home/discourse-plugins-mono
      - rm -rf $home/plugins/snowball $home/plugins/discourse-snowball
      - cp -a $home/discourse-plugins-mono/snowball $home/plugins/discourse-snowball
```

然后 `cd /var/discourse && ./launcher rebuild app`（迁移会在 bootstrap 阶段自动执行）。

## 首次使用

1. **后台 → 群组**：创建 `verified-employees`（验证群）和 `former-employees`（过期群，启用有效期时需要）
   > 群组不存在时不会报错，只是**不会加群**，仅在 `production.log` 留一行 `[discourse-snowball] 群组不存在`
2. **后台 → 插件 → Snowball**：上传种子 JSON 导入种子库
   > 未导入前用户点「开始验证」会返回「种子库为空或可用种子不足」
3. **后台 → 设置 → 插件**：确认群组名、信任等级、次数限制、有效期

## 种子数据格式

后台页面上传的 JSON 支持以下任意组合（按 `employee_id` 合并覆盖，不会删除已有记录）：

```jsonc
// 上游管理接口 GET /api/admin/seeds 的导出
{ "total": 228, "surname_stats": [...], "seeds": [
  { "employee_id": "00518671", "surname": "丁", "confidence": 100,
    "status": "active", "resigned_signals": 0, "in_active_pool": 1 }
]}

// 观察库 / 离职观察（可选）
{ "observations":          [ { "employee_id": "00647710", "votes": { "王": 1 }, "total": 1 } ] }
{ "resigned_observations": [ { "employee_id": "00625439", "resigned_votes": 1,
                               "probe_weight": 0.95, "range_radius": 1000 } ] }
```

也可以直接传 `seeds` 数组本身。`surname` 为空、或 `employee_id` 无法归一化成 8 位的行会被跳过。

## 站点设置

| 设置项 | 说明 | 默认值 |
|--------|------|--------|
| `snowball_enabled` | 启用插件 | `true` |
| `snowball_verified_group` | 验证后加入的群组名 | `verified-employees` |
| `snowball_trust_level` | 验证后信任等级（0 = 不调整） | `2` |
| `snowball_show_nav_link` | 显示导航入口 | `true` |
| `snowball_daily_attempt_limit` | 每天最多提交次数（0 = 不限） | `3` |
| `snowball_weekly_attempt_limit` | 每周最多提交次数（0 = 不限） | `3` |
| `snowball_validity_days` | 验证有效期（天），**0 = 永久有效** | `180` |
| `snowball_expired_group` | 过期后移入的群组（留空 = 只移出） | 空 |
| `snowball_seed_questions` | 每份验证的种子题数量（0~9） | `3` |
| `snowball_probe_questions` | 每份验证的探测题数量（0~9） | `2` |
| `snowball_pass_threshold` | 通过需要答对的种子题数量（0~9） | `2` |
| `snowball_block_size` | 区块粒度：同号段大小。100=只差后 2 位 / 1000=后 3 位 / 10000=后 4 位 | `1000` |

出题量、通过线、区块粒度都可以在后台随时调整，例如「种子题 2 + 探测题 3 + 通过线 1」就是出 5 道题、答对 1 道即通过。
> 通过线为 0 时任何人提交都算通过；通过线大于种子题数量时永远无法通过（后台设置说明里也写了）。
> 区块粒度不能小于种子库的疏密程度：比如种子库只有 228 条时，100 号段里凑不出 3 道种子题，插件会自动退化为全局随机出题（不会报错）。

## 数据表

| 表 | 用途 |
|---|---|
| `snowball_seeds` | 种子库（工号 → 姓氏、置信度、是否在出题池） |
| `snowball_observations` | 探测题收到的姓氏票（锚点） |
| `snowball_resigned_observations` | 探测题「已离职」票与探测权重 |
| `snowball_challenges` | 进行中的挑战（5 分钟有效期、判定结果） |
| `snowball_verification_attempts` | 提交记录，用于日 / 周次数限制 |

验证状态记录在 Discourse 的用户自定义字段里：`snowball_verified_at`、`snowball_expired_at`。

## 后台页面

后台 → 插件 → Snowball（`/admin/plugins/snowball`）：

- 顶部一行统计：种子总数 / 可用种子 / 观察库锚点 / 离职观察锚点 / 最近导入时间 / **已验证用户 / 提交次数**
- **查看种子库 / 查看观察库 / 查看离职库 / 查看验证记录** 四个按钮展开对应清单，再点一次收起。清单表头吸顶、区域独立滚动（最长 28rem），支持翻页；前三个按工号筛选，验证记录按用户名筛选
- **验证记录**里一行 = 一次提交：`提交时间 / 用户 / 结果（通过·未通过）/ 验证通过时间 / 有效期至`，最新在前
- 下方是 JSON 上传区（导入）和 `刷新统计` / `清空种子库`。导入或清空时若清单正打开会自动刷新

## 管理接口（后台页面使用，仅管理员）

| 方法 | 路径 | 说明 |
|---|---|---|
| `GET` | `/admin/snowball/seeds` | 统计（**不返回种子内容**） |
| `POST` | `/admin/snowball/seeds` | 导入 JSON（参数 `payload`） |
| `DELETE` | `/admin/snowball/seeds` | 清空种子库 / 观察库 / 挑战 |
| `GET` | `/admin/snowball/library/seeds` | 种子库清单 |
| `GET` | `/admin/snowball/library/observations` | 观察库清单 |
| `GET` | `/admin/snowball/library/resigned_observations` | 离职观察库清单 |
| `GET` | `/admin/snowball/library/verifications` | 验证记录（每次提交一行，最新在前） |

四个 `library` 接口都是只读分页查询，参数相同：

| 参数 | 说明 | 默认 |
|---|---|---|
| `page` | 页码（从 1 开始） | `1` |
| `per_page` | 每页行数，上限 200 | `50` |
| `q` | 筛选：前三个按工号（服务端只保留数字字符，如 `5186`），验证记录按用户名 | 空 |

返回 `{ "total": 228, "page": 1, "per_page": 50, "items": [ … ] }`：

- `seeds`：`employee_id`、`surname`、`confidence`、`status`、`in_active_pool`、`resigned_signals`、`updated_at`
- `observations`：`employee_id`、`votes`（`{"王": 1}`）、`total`、`updated_at`
- `resigned_observations`：`employee_id`、`resigned_votes`、`probe_weight`、`range_radius`、`updated_at`

排序：种子库按工号升序；观察库按总票数降序；离职观察库按离职票数降序；验证记录按提交时间降序。

验证记录的字段：`created_at`（提交时间）、`username`、`user_id`、`outcome`（`passed` / `failed`）、`passed`、`verified_at`（该用户当前是否已验证）、`expires_at`（有效期至）。

## 用户流程

1. 登录用户打开 `/snowball` 或点击导航「员工验证」
   - **未验证（或已过期）**：显示今日 / 本周剩余次数 + 「开始验证」按钮
   - **已验证且在有效期内**：只显示「已完成验证」+ 验证通过时间与有效期，不再显示次数和按钮
2. 点「开始验证」→ 5 分钟内为 5 个工号填写姓氏（复姓填首字、英文名填首字母），或勾「已离职」
   - 输入框只保留一个字符；**拉丁字母自动转成大写**（`l` → `L`），判定时大小写不敏感
3. 提交：3 道种子题答对 2 道即通过
4. 通过 → 记录验证时间、加入群组、提升信任等级；后台「查看验证记录」可看到每一次提交（用户、结果、时间）

## 故障排查

- **提示「种子库为空」**：还没有在后台导入种子 JSON
- **验证通过但没进群**：检查 `snowball_verified_group` 指向的群组是否存在
- **次数用完了**：日 / 周限制按站点时区的自然日 / 自然周计算；可在设置里调大或改为 0（不限）
- **用户已验证但想重考**：清除该用户的 `snowball_verified_at`，或把 `snowball_validity_days` 调小后等过期
- **种子置信度下降**：连续答错的种子置信度 -3，降到 0 自动移出出题池（`in_active_pool`）

## 目录结构

```
snowball/
  plugin.rb
  config/settings.yml
  config/locales/*
  db/migrate/*
  app/models/snowball_{seed,observation,resigned_observation,challenge,verification_attempt}.rb
  app/controllers/snowball_controller.rb
  app/controllers/snowball/admin_controller.rb
  app/jobs/scheduled/snowball_expire_verifications.rb
  lib/snowball_{verifier,seed_import,limits,promoter}.rb
  assets/javascripts/discourse/...        # 前台页面
  assets/stylesheets/common/snowball.scss
  admin/assets/javascripts/discourse/
    initializers/snowball-admin-nav.js
    snowball-admin-route-map.js
    controllers/admin-plugins/show/snowball.js   # ★ 路由 / 控制器 / 模板三者
    routes/admin-plugins/show/snowball.js        #   必须同名同目录。写成扁平的
    templates/admin-plugins/show/snowball.gjs    #   admin-plugins-show-snowball.js
                                                 #   会触发关键废弃告警
                                                 #   discourse.deprecated-resolver-normalization
```

> 后台那三个文件的名字不是随便起的：Discourse 的 resolver 只认 `admin-plugins/show/<name>` 这一种写法
> （官方插件 discourse-ai 也是这个布局）。改名后会退回旧的查找方式，并在后台弹出
> 「包含需要更新的代码」的管理员通知。

## 相关链接

- 插件仓库：https://github.com/gapdo-alt/discourse-plugin
