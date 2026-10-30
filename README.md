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
├── cad.html                     # CAD 制图速查站入口（附加内容，非主体）
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

## 六个模块

| 模块 | 内容 |
|---|---|
| 今日总览 | 生活指数、快速记一笔、今日习惯与待办、最近记录 |
| 记账理财 | 收支流水、月度预算、月度对比、分类筛选、消费结构饼图 |
| 习惯健康 | 自定义习惯（勾选 / 计数 / 数值三种打卡）、30 天热力图；子页：健身记录与减脂档案 |
| 学习资料查询 | 内嵌 CAD 制图速查 5 个页面 |
| 日程统筹 | 按日期与清单组织待办、一周日历、智能清单 |
| 待买与收藏 | 待买清单（状态、数量、预估价）；书影音（封面墙 / 列表双视图、评分短评、年度统计） |

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

`supabase-harden.sql` 把策略换成：请求头必须带 `x-app-key` 且等于口令才放行。口令不写进仓库，只存在：

- 本机 localStorage（输一次就记住）
- 你的专属链接 `life-all-in-one.html?k=<口令>`（打开一次即写入缓存，地址栏里的口令会被自动抹掉）

新设备第一次打开会弹「输入同步口令」，粘贴即可。口令忘了就改 SQL 里的字符串重新跑一遍。

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
