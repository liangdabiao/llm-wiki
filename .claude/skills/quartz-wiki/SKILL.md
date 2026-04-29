---
name: quartz-wiki
description: Set up and deploy Quartz v4 static site for markdown wikis. Use when the user says "部署wiki", "quartz", wants to publish wiki as a website, deploy to Cloudflare Pages/Vercel/GitHub Pages, configure Quartz, fix Quartz build errors, or troubleshoot Quartz issues. Covers initialization, configuration, YAML frontmatter fixes, wikilink support, content management, and deployment.
---

# Quartz Wiki — 静态站点部署器

将已有的 Markdown Wiki 部署为 Quartz v4 静态网站，支持双向链接、关系图谱、全文搜索。

## 工作流

当用户说「部署 wiki」「quartz」「发布网站」时：

### Phase 1: 初始化

```bash
# 方式1：git clone（需要翻墙时用 --depth 1 加速）
git clone --depth 1 --branch v4 https://github.com/jackyzha0/quartz.git
cd quartz
npm i

# 方式2：如果 clone 不可用，手动下载 v4 分支 zip 解压
```

**前提条件**：Node.js v22+, npm v10.9.2+

### Phase 2: 内容接入

将已有 wiki 内容放入 `quartz/content/` 目录。

**关键决策**：
- **Symlink**（开发用）：`ln -s ../wiki content` — 但 Windows 上可能缓存旧内容，出问题时换 copy
- **Copy**（部署用）：`cp -r ../wiki content` — 每次构建前同步
- **Git 管理**（生产推荐）：content 目录纳入 git，CI/CD 自动同步

**必须排除的目录**：在 `quartz.config.ts` 的 `ignorePatterns` 中添加 `raw`、`private`、`templates` 等。

详见 [quartz-setup.md](references/quartz-setup.md) 的完整配置指南。

### Phase 3: Frontmatter 修复

Quartz 对 YAML frontmatter 有严格要求。**部署前必须检查并修复以下问题**：

| 问题 | 症状 | 修复 |
|------|------|------|
| `aliases:` 字段冲突 | 构建报错 "ENOTEMPTY" / alias emitter 崩溃 | **重命名为 `also_known_as:`** |
| YAML `#` 注释 | 构建报错 "missed comma" | 去掉 `#` 或用引号包裹 `"#6539"` |
| 内联列表 `[a, b]` | 偶发 YAML 解析失败 | 改为标准 `- a\n- b` 格式 |
| 空值字段 | 解析异常 | 设为空字符串或删除 |

详见 [quartz-troubleshooting.md](references/quartz-troubleshooting.md) 的完整修复脚本。

### Phase 4: 构建与验证

```bash
# 清理缓存（重要！否则可能读到旧内容）
rm -rf .quartz-cache public

# 构建
npx quartz build

# 本地预览（需要单独启动服务器）
npx quartz build --serve   # 不推荐，会清空 public
# 或构建后用 python 起服务器：
python -m http.server 8080 -d public
```

**验证清单**：
- [ ] 首页正常显示
- [ ] 侧边栏导航可用
- [ ] [[wikilinks]] 双向链接跳转正确
- [ ] 关系图谱（Global Graph）弹出正常
- [ ] 全文搜索可用
- [ ] 图片正常加载
- [ ] 暗色模式切换正常

### Phase 5: 部署

详见 [quartz-deployment.md](references/quartz-deployment.md)。

## 配置要点

### 关键配置项（quartz.config.ts）

```typescript
{
  configuration: {
    pageTitle: "你的Wiki名称",       // 站点标题
    locale: "zh-CN",                  // 中文支持
    baseUrl: "https://your-domain.com", // 不能为空！否则 404 页面构建崩溃
    ignorePatterns: ["raw", "private", "templates"],  // 排除目录
  },
  plugins: {
    transformers: [
      Plugin.ObsidianFlavoredMarkdown(),  // 支持 [[wikilinks]]
      Plugin.GitHubFlavoredMarkdown(),
      Plugin.TableOfContents(),            // 自动生成目录
      Plugin.CrawlLinks({ markdownLinkResolution: "shortest" }),
      // Plugin.Latex(),                   // 如需数学公式
    ],
  },
}
```

### Frontmatter 规范（给内容文件的）

```yaml
---
title: "页面标题"          # 必填，显示在页面和侧边栏
date: 2026-04-24          # 用于排序
tags:                     # 可选，用于标签页
  - wiki
  - lego
---
```

**禁止使用的 frontmatter 字段**（与 Quartz 冲突）：
- `aliases:` → 用 `also_known_as:` 替代
- `slug:` → 用文件名控制 URL
- `publish:` → 用 `draft: true` 控制草稿

## 常见问题速查

| 问题 | 解决方案 |
|------|----------|
| `npx create-quartz` 404 | 这个包不存在，用 `git clone` |
| `git clone` 超时 | 用 `--depth 1` 浅克隆 |
| 构建报错 "missed comma" | YAML `#` 注释问题，修复 frontmatter |
| 构建报错 "ENOTEMPTY" | `aliases:` 字段冲突，改名为 `also_known_as:` |
| 构建报错 "Invalid URL" | `baseUrl` 为空，设置有效 URL |
| 内容没更新 | 清理 `.quartz-cache`，Windows symlink 换 copy |
| 图片不显示 | 检查图片 URL 是否可访问，外链图片无需额外配置 |
| 中文乱码 | 设置 `locale: "zh-CN"`，确保 md 文件是 UTF-8 编码 |
| 构建产物太大 | 检查是否有大文件被意外包含，用 `ignorePatterns` 排除 |
