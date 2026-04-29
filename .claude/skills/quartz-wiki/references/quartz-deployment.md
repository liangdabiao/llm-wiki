# Quartz 部署指南

## Cloudflare Pages

### 步骤

1. 在 GitHub 创建仓库，推送 Quartz 项目
2. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com)
3. **Workers & Pages** → **Create** → **Pages** → **Connect to Git**
4. 选择 GitHub 仓库
5. 配置构建设置：

| 设置 | 值 |
|------|-----|
| Production branch | `main` |
| Framework preset | `None` |
| Build command | `npx quartz build` |
| Build output directory | `public` |

6. **Save and Deploy**

### 自定义域名

在 Pages 项目 → **Custom domains** → 添加你的域名。Cloudflare 会自动配置 SSL。

### 构建命令（依赖 git 时间的场景）

如果页面排序依赖 git commit 时间：

```bash
git fetch --unshallow && npx quartz build
```

（Cloudflare Pages 默认 shallow clone，不含完整 git 历史）

## Vercel

```bash
# 安装 Vercel CLI
npm i -g vercel

# 部署
cd quartz
vercel

# 后续更新
vercel --prod
```

Vercel 会自动检测框架，如果识别失败手动设置：
- Build Command: `npx quartz build`
- Output Directory: `public`

## GitHub Pages

### 方式1：GitHub Actions

在仓库中创建 `.github/workflows/deploy.yml`：

```yaml
name: Deploy Quartz

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # 完整历史，用于日期排序
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - run: npm ci
      - run: npx quartz build
      - uses: actions/upload-pages-artifact@v3
        with:
          path: public
  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

在仓库设置 → Pages → Source 选 **GitHub Actions**。

### 方式2：手动部署

```bash
npx quartz build
cd public
git init
git checkout -b gh-pages
git add .
git commit -m "deploy"
git push -f origin gh-pages
```

## Netlify

1. **New site** → **Import an existing project**
2. 连接 GitHub 仓库
3. Build settings：
   - Build command: `npx quartz build`
   - Publish directory: `public`

## 本地预览

```bash
# 构建后用任意静态服务器
npx quartz build
# Python
python -m http.server 8080 -d public
# Node
npx serve public
# PHP
php -S localhost:8080 -t public
```

然后在浏览器打开 `http://localhost:8080`。

## CI/CD 注意事项

### 内容同步策略

如果你的 wiki 内容在单独的仓库：

**方案A：Git Submodule**
```bash
cd quartz
git submodule add https://github.com/you/wiki-content.git content
git commit -m "add content submodule"
```

**方案B：CI 中复制**
```yaml
# 在 build 前拉取内容
- name: Sync content
  run: |
    git clone https://github.com/you/wiki-content.git content
```

**方案C：构建脚本**
```bash
#!/bin/bash
# sync-content.sh
rm -rf content
cp -r /path/to/wiki content
npx quartz build
```

### 环境变量

| 变量 | 用途 | 默认值 |
|------|------|--------|
| `QUARTZ_BUILD_CONCURRENCY` | 构建并发数 | CPU 核心数 |
| `NODE_VERSION` | Node 版本要求 | >= v22 |

## 部署检查清单

- [ ] `baseUrl` 设置为正确的域名
- [ ] `ignorePatterns` 排除了 `raw/` 等非内容目录
- [ ] 所有 frontmatter 中 `aliases:` 已改为 `also_known_as:`
- [ ] YAML `#` 值已用引号包裹
- [ ] `npx quartz build` 构建成功无报错
- [ ] 首页、章节页、概念页均正常显示
- [ ] [[wikilinks]] 双向链接跳转正确
- [ ] 图片加载正常（外链或本地）
- [ ] 搜索功能可用
- [ ] 关系图谱弹出正常
- [ ] 移动端响应式布局正常
- [ ] 暗色模式切换正常
