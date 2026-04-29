# Quartz v4 完整配置指南

## 安装

```bash
# 前提：Node.js v22+, npm v10.9.2+
node -v
npm -v

# 克隆（浅克隆加速）
git clone --depth 1 --branch v4 https://github.com/jackyzha0/quartz.git
cd quartz
npm i
```

如果 git clone 不可用：
1. 浏览器访问 https://github.com/jackyzha0/quartz/archive/refs/heads/v4.zip
2. 解压到项目目录
3. `cd quartz && npm i`

## 内容目录结构

```
quartz/
├── quartz.config.ts      # 主配置文件
├── content/               # ← 你的 wiki 内容放这里
│   ├── index.md           # 首页
│   ├── vol1-architect/    # 按卷组织
│   ├── vol2-microcities/
│   ├── concepts/          # 概念条目
│   └── indexes/           # 索引
├── quartz/                # Quartz 引擎（不要修改）
├── public/                # 构建产物（自动生成）
└── package.json
```

## 接入已有 Wiki 内容

### 方式1：复制（推荐用于首次部署）

```bash
rm -rf content
cp -r /path/to/your/wiki content
```

### 方式2：Symlink（开发阶段方便同步）

```bash
rm -rf content
ln -s /path/to/your/wiki content
```

**Windows 注意**：symlink 可能缓存旧内容。如果修改了源文件但构建结果没变，换用复制。

### 方式3：Git 管理（生产推荐）

```bash
# 将 content 目录设为独立 git 仓库或子模块
cd content
git init
git add .
git commit -m "init content"
```

## 推荐的 quartz.config.ts 配置

```typescript
import { QuartzConfig } from "./quartz/cfg"
import * as Plugin from "./quartz/plugins"

const config: QuartzConfig = {
  configuration: {
    pageTitle: "你的 Wiki 名称",
    pageTitleSuffix: "",
    enableSPA: true,
    enablePopovers: true,
    locale: "zh-CN",
    baseUrl: "https://your-domain.com",  // 必须设置，不能为空
    ignorePatterns: ["raw", "private", "templates", ".obsidian", "drafts"],
    defaultDateType: "modified",
    theme: {
      fontOrigin: "googleFonts",
      cdnCaching: true,
      typography: {
        header: "Schibsted Grotesk",
        body: "Source Sans Pro",
        code: "IBM Plex Mono",
      },
      colors: {
        lightMode: {
          light: "#faf8f8",
          lightgray: "#e5e5e5",
          gray: "#b8b8b8",
          darkgray: "#4e4e4e",
          dark: "#2b2b2b",
          secondary: "#d4380d",
          tertiary: "#fa8c16",
          highlight: "rgba(212, 56, 13, 0.12)",
          textHighlight: "#fff23688",
        },
        darkMode: {
          light: "#161618",
          lightgray: "#393639",
          gray: "#646464",
          darkgray: "#d4d4d4",
          secondary: "#ff7a45",
          tertiary: "#ffc53d",
          highlight: "rgba(255, 122, 69, 0.12)",
          textHighlight: "#b3aa0288",
        },
      },
    },
  },
  plugins: {
    transformers: [
      Plugin.FrontMatter(),
      Plugin.CreatedModifiedDate({
        priority: ["frontmatter", "git", "filesystem"],
      }),
      Plugin.SyntaxHighlighting({
        theme: { light: "github-light", dark: "github-dark" },
        keepBackground: false,
      }),
      Plugin.ObsidianFlavoredMarkdown({ enableInHtmlEmbed: false }),
      Plugin.GitHubFlavoredMarkdown(),
      Plugin.TableOfContents(),
      Plugin.CrawlLinks({ markdownLinkResolution: "shortest" }),
      Plugin.Description(),
      // Plugin.Latex({ renderEngine: "katex" }),  // 需要数学公式时启用
    ],
    filters: [Plugin.RemoveDrafts()],
    emitters: [
      Plugin.AliasRedirects(),
      Plugin.ComponentResources(),
      Plugin.ContentPage(),
      Plugin.FolderPage(),
      Plugin.TagPage(),
      Plugin.ContentIndex({
        enableSiteMap: true,
        enableRSS: true,
      }),
      Plugin.Assets(),
      Plugin.Static(),
      Plugin.Favicon(),
      Plugin.NotFoundPage(),
      // Plugin.CustomOgImages(),  // 启用会显著增加构建时间
    ],
  },
}

export default config
```

## 首页模板

```markdown
---
title: "你的 Wiki 名称"
date: 2026-04-24
tags:
  - wiki
---

# 你的 Wiki 名称

> 一句话描述你的 wiki。

## 快速导航

| 板块 | 说明 | 链接 |
|------|------|------|
| 章节目录 | 按卷/章浏览 | [查看 →](vol1-architect/) |
| 概念索引 | 核心知识条目 | [查看 →](concepts/) |
| 全局索引 | 知识图谱 | [查看 →](indexes/index) |
```

## 构建命令

```bash
# 清理缓存后构建（推荐每次构建前执行）
rm -rf .quartz-cache public && npx quartz build

# 仅构建（如果确认缓存干净）
npx quartz build

# 构建并本地预览（端口 8080）
npx quartz build --serve --port 8080

# 或构建后用其他服务器预览
npx quartz build
python -m http.server 8080 -d public
```

## 目录组织建议

Quartz 会自动根据文件夹结构生成侧边栏导航和文件夹页面：

```
content/
├── index.md              → 首页
├── concepts/             → 自动生成 concepts 文件夹页面（列出所有概念）
│   ├── SNOT技法.md
│   └── 齿轮传动.md
├── vol1-architect/       → 自动生成文件夹页面
│   ├── 新古典主义.md
│   └── 现代主义.md
└── indexes/
    └── index.md          → 全局索引页
```
