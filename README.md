# LX集 · 生活工作台

一个个人生活工作台：记账理财、习惯打卡、健身记录、日程统筹、待买清单、书影音收藏，六个模块统一入口，数据存在自己的 Supabase 数据库里，手机和电脑打开是同一份。

纯静态页面 + 云端数据库，无框架、无构建。克隆下来把整个目录丢到任意 Web 服务器（Nginx / Apache / 对象存储 / GitHub Pages）即可。

## 在线地址

<https://lxun602.github.io/people-net/>

访问根目录会自动跳转到 `life-all-in-one.html`。

## 目录结构

```
people-net/
├── index.html                   # 入口：自动跳转进生活工作台
├── life-all-in-one.html         # 生活工作台本体（6 模块，单文件）
├── cad.html                     # CAD 制图速查站入口（含全站搜索，附加内容）
├── pages/                       # CAD 速查的 4 个子页
│   ├── drawing-commands.html
│   ├── modify-commands.html
│   ├── blocks.html
│   └── text-and-dimension.html
├── supabase-schema.sql          # 建表补丁：设置表 / 习惯唯一约束 / 数量改文本
├── supabase-harden.sql          # 加固补丁：加同步口令，挡住未授权读写
├── .github/workflows/deploy.yml # GitHub Pages 自动部署
├── .nojekyll
├── .gitignore
└── README.md
```

## 七个模块

| 模块 | 内容 |
|---|---|
| 今日总览 | 生活指数、快速记一笔、今日习惯与待办、最近记录 |
| 记账理财 | 收支流水、月度预算、月度对比、分类筛选、消费结构饼图 |
| 习惯健康 | 自定义习惯（勾选 / 计数 / 数值三种打卡）、30 天热力图；子页：健身记录与减脂档案 |
| 学习资料查询 | 内嵌 CAD 制图速查 5 个页面 |
| 日程统筹 | 按日期与清单组织待办、一周日历、智能清单 |
| 待买清单 | 物品、数量、预估价、待买 / 已买状态、预计预算 |
| 书影音 | 状态（想看 / 在看 / 看完 / 弃了）、五星评分、一句话短评、封面上传、封面墙与列表双视图、年度统计（今年看完 / 平均分 / 最爱类型 / 评分分布） |

## 手机端

工作台在 860 / 720 / 560 / 380 四个宽度档位做了补充排版：顶栏两行不重叠、7 个底部导航按钮压到 60px 高度仍可点、表单双列在 720px 以下自动变单列、快捷入口在 560px 以下变两列、设置弹窗按钮窄屏竖排且最小 46px 高（够手指点）。桌面端规则未改。

CAD 速查站的顶部导航在窄屏改成横向滚动而不是直接隐藏，搜索输入框字号固定 16px，避免 iOS 点输入时自动放大页面。

## CAD 速查站的搜索

`cad.html` 顶部输入框，输入即搜，覆盖：本页 4 张卡片的标题/描述/标签、快捷直达、顶部导航、页脚，以及 `pages/` 下 4 份图解的**全部章节标题和正文**。

- 索引由 `_src/build_cad.py` 从子页自动抽取生成并嵌进 HTML，零网络请求，改了子页重跑脚本即可。
- 支持空格分隔的多词（需全部命中）、结果高亮、命中处上下文摘要、结果计数。
- 有「清空」按钮、结果区「清空搜索」、Esc 清空、Enter 打开第一条。
- 无结果时显示提示和 10 个常见关键词，点一下直接搜。
- 用户输入一律转义后再写进页面，避免注入。

## 数据存哪

数据全部在 **Supabase（Postgres）**，页面通过 REST 直连读写，不依赖任何浏览器插件或平台运行时。

| 表 | 内容 |
|---|---|
| `money_records` | 收支流水 |
| `schedules` | 日程待办 |
| `habit_logs` | 习惯打卡（日期 + 习惯 唯一） |
| `fitness_logs` | 体重体脂记录 |
| `shopping_items` | 待买清单 |
| `media_items` | 书影音收藏 |
| `app_settings` | 预算、外观、自定义习惯、周计划（单行 `id='default'`，整包 JSON） |

浏览器 localStorage 只做首屏缓存，真正的数据源是云端。换设备、换浏览器都是同一份数据。

断网或写失败时：顶部弹红色横幅说明失败环节，右上角显示「同步失败」，点「重试同步」会把本机没传上去的内容补传。

## 从零搭一遍

### 1. 建数据库

在 Supabase 建项目，拿到 **Project URL** 和 **publishable key**（`sb_publishable_` 开头，**不要**用 `sb_secret_`，那把钥匙会绕过权限且不能进浏览器）。

SQL Editor 里依次跑 `supabase-schema.sql` 和 `supabase-harden.sql`。

### 2. 建表

```sql
create table public.money_records (
  id uuid primary key default gen_random_uuid(),
  "日期" date not null default current_date,
  "分类" text default '其他',
  "金额" numeric(12,2) default 0,
  "备注" text default '',
  created_at timestamptz default now()
);
-- schedules / habit_logs / fitness_logs / shopping_items / media_items 同理
-- 全部 enable row level security
```

字段中文名与页面一一对应，改字段名就要同步改页面。

### 3. 接上页面

改 `life-all-in-one.html` 顶部三行：

```js
var SUPABASE_URL = 'https://<你的项目>.supabase.co/rest/v1';
var SUPABASE_KEY = 'sb_publishable_<你的钥匙>';
```

### 4. 加固（强烈建议）

仓库是公开的，钥匙也在页面里。如果表的策略是「任何人可读写」，谁拿到链接就能读到你全部数据。

`supabase-harden.sql` 把策略换成：请求头必须带 `x-app-key` 且等于口令才放行。口令不写进仓库，只存在每台设备自己的浏览器里。

### 5. 连接设置：不用链接，直接打开域名

已部署域名以 `llxcad.cn` 为例。**直接打开 `https://llxcad.cn` 就行，不需要任何带参数的链接。**

1. 第一次打开：页面自动弹出「连接这台设备」，显示当前站点 `llxcad.cn`，状态是「这台设备还没设置」。
2. 把同步口令粘进输入框，点「保存并连接」。状态会变成「已自动生效」，弹出提示「已保存，以后这台设备打开会自动生效」。
3. 之后刷新、关掉重开、再进这个网址：不再弹窗，右上角状态灯显示「已自动生效」，并提示「已自动使用这台设备保存的配置」。
4. 想改或想清除：点右上角齿轮「连接设置」，里面有「显示口令」「清除本机配置」「关闭」。清除后回到第 1 步。

配置存在各设备浏览器的 localStorage（浏览器自带的一小块本机存储），**每台设备各存各的，互不影响**。换手机、换电脑要各自填一次；清了浏览器数据也会回到第 1 步。

兼容旧方式：`life-all-in-one.html?k=<口令>` 这种链接仍然能用，打开一次后地址栏里的口令会被自动抹掉，之后同样不用再带。口令忘了就改 SQL 里的字符串重新跑一遍。

三种状态在页面上都看得见：顶栏齿轮旁的状态灯（灰=未设置、蓝=已保存、绿=已自动生效、红=口令不对）、弹窗里的状态条、以及操作后的提示条。断网时不会把已存的配置误判成口令错误清掉。

## 部署

### GitHub Pages

`main` 分支每次推送触发 `.github/workflows/deploy.yml`，约 1 分钟上线。Pages 的 **Build and deployment → Source** 设为 **GitHub Actions**，仓库需为 public（免费版限制）。

### 自己的服务器

把整个目录传上去，Web 服务器根目录指向它即可。Nginx 参考：

```nginx
server {
    listen 80;
    server_name your.domain;
    root /var/www/people-net;
    index index.html;
    try_files $uri $uri/ =404;
}
```

因为页面直接 fetch Supabase，不需要任何后端进程，静态托管就够。

## 维护

- **改文案**：同一句中文通常出现在三处——HTML 静态节点、`data-title` 之类的属性、`EN_I18N` 英文词典，要一起改。
- **加模块**：加一对 `data-nav="xxx"` 按钮和 `<section class="view" id="view-xxx" data-title="...">` 即可，`switchView()` 是按 id 通用切换的，不用改 JS。
- **更新内嵌的 CAD 内容**：CAD 页面是嵌在 `<template id="cad-tpl-N">` 里的，源站更新后需要重新生成嵌入内容。
