---
source_url: https://bilibili.com/video/BV1DP7JzAE7k/
source_type: article
ingest_date: 2026-04-29
---

# 1分钟生成架构图？程序员AI绘图保姆级教程

## 推荐工具组合

Cursor + Claude 4效果最佳

## AI画图本质

让AI生成各种绘图工具能理解的文本代码，然后导入对应工具渲染

## 五大类AI画图方法

### 一、文本绘图（高级程序员最爱）

#### 1. Mermaid - 最流行的文本绘图工具
- GitHub/GitLab原生支持
- 语法简单直观
- 支持：流程图、架构图、时序图、甘特图、饼图、Git分支图、ER图

示例提示词：
```
请用 Mermaid 语法画用户登录流程图：
1.输入账号密码 2.前端校验 3.发送请求后端 4.后端验证 5.成功生成token 6.失败返回错误
```

渲染工具：语雀、Typora、Mermaid Live Editor

#### 2. PlantUML - 专业UML绘图
- 擅长UML图、时序图、系统架构图
- 语法专业规范，图表更精美

#### 四大文本绘图工具对比

| 特性 | Mermaid | PlantUML | Flowchart | Graphviz |
|---|---|---|---|---|
| 图表类型 | 流程时序甘特等 | UML全系列架构图 | 仅流程图 | 各类，极灵活 |
| 语法难度 | 简单直观 | 中等UML规范 | 极简单 | 较复杂 |
| 生态支持 | GitHub原生支持 | 需要插件 | 一般 | 广泛支持 |
| 学习成本 | 低 | 中 | 极低 | 高 |

建议：日常Mermaid，专业UML用PlantUML

### 二、网页绘图

本质：图片即网站，生成HTML+CSS+JS代码

1. 原生网页绘图 - HTML+CSS+JS，配合ECharts/D3.js做数据可视化大屏
2. SVG矢量图 - 无限缩放不失真，UI素材/Logo/架构图
3. Canvas动态绘图 - 像素级控制，适合动画和游戏

### 三、思维导图

AI直接生成可导入XMind格式，或Markdown格式导图

示例：微服务架构设计思维导图提示词

### 四、专业绘图工具

AI + draw.io（免费开源）
- 自由度极高，导入XML代码到draw.io二次编辑

### 五、Emoji创意绘图

Emoji纯文本流程图

## 四大高级技巧

### 1. 提供示例图让AI模仿
截图给AI让它生成同款风格

### 2. 截图标注精准修改
红圈标注问题点让AI精准修改

### 3. 配置专业系统预设
配置专业架构师绘图预设到Cursor Rules

### 4. 组合生成：同时输出Mermaid/PlantUML/draw.io多格式
