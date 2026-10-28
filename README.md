# CAD 制图速查手册（静态站点）

一套 CAD 常用操作的中文图解速查站点，纯静态 HTML，无框架、无构建、无外部依赖，克隆下来双击 `index.html` 就能看。

## 目录结构

```
people-net/
├── index.html                        # 总入口（速查首页）
├── pages/
│   ├── drawing-commands.html         # 绘图命令图解
│   ├── modify-commands.html          # 二维图形修改命令图解
│   ├── blocks.html                   # 图块使用图解
│   └── text-and-dimension.html       # 文字样式与尺寸标注图解
├── .github/workflows/deploy.yml      # GitHub Pages 自动部署
├── .nojekyll                         # 关闭 Jekyll 处理，避免静态资源被过滤
├── .gitignore
└── README.md
```

## 页面来源

5 个页面均从 WorkBuddy 空间导出，整理时做了三件事：

1. 去掉平台注入脚本 `/page/page_comm/inject.js`（本地和 GitHub Pages 上都不存在该路径，留着会 404）；
2. 去掉平台编辑态标记（`data-page-node-id`、`pnid` 注释）；
3. 页间跳转从 `https://workbuddy.link/p/<id>` 改为本地相对路径，站点可离线使用。

| 原页面 | 现路径 |
|---|---|
| CAD制图速查总入口 | `index.html` |
| CAD绘图命令图解 | `pages/drawing-commands.html` |
| CAD二维图形修改命令图解 | `pages/modify-commands.html` |
| CAD图块使用图解 | `pages/blocks.html` |
| CAD文字样式与尺寸标注图解 | `pages/text-and-dimension.html` |

## 本地预览

直接双击 `index.html` 即可。需要用本地服务器（例如检查相对路径）时：

```bash
python3 -m http.server 8000
# 浏览器打开 http://localhost:8000
```

## 部署

`main` 分支每次推送都会触发 `.github/workflows/deploy.yml`：检出代码 → 打包为 Pages 制品 → 发布到 GitHub Pages。

仓库需在 **Settings → Pages → Build and deployment → Source** 选择 **GitHub Actions**（私有仓库需账户支持 Pages，或把仓库改为公开）。

## 维护

新增页面：把 HTML 放进 `pages/`，并在 `index.html` 里加一条指向 `pages/<文件名>.html` 的链接，推送即自动上线。
