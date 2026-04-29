---
tags: [DeepSeek, Python, PyCharm, Ollama, 本地部署, CodeGPT]
created: 2026-04-29
updated: 2026-04-29
source_path: raw/articles/2026-04-29-deepseek-python-local-setup.md
---

# DeepSeek 本地部署完整方案：PyCharm + CodeGPT + Ollama，零成本编程辅助

> 面向普通电脑用户的 DeepSeek R1 本地化部署方案，无 GPU 也能 1-2 秒快速响应

## 核心观点

1. **零成本方案组合**：DeepSeek-R1:1.5b（开源免费）+ PyCharm Community Edition（免费）+ CodeGPT（免费插件）= 完全零成本

2. **小参数模型同样强大**：DeepSeek R1 解决了以往小模型回复 Token 短、质量低的问题，1.5b 参数版本在普通无 GPU 电脑上也能流畅运行

3. **本地部署三大优势**：
   - 数据安全，代码不上传第三方
   - 无 API 费用，完全免费
   - 1-2 秒超低延迟，比云端更快

## 实操内容

### 技术栈选型

| 组件 | 选型 | 版本 | 说明 |
|------|------|------|
| 大模型 | DeepSeek-R1 | 1.5b 版本 | 7个版本可选，1.5b 版本普通电脑无 GPU 可运行 |
| IDE | PyCharm | Community 社区版 | 完全免费，专业 IDE 功能 |
| 插件 | CodeGPT | 最新版 | UI 最好用的大模型编程插件 |
| 运行环境 | Ollama | 最新版 | 本地大模型管理工具 |

### 三步搭建流程

**第一步：安装 PyCharm Community**

1. 官网下载 PyCharm 社区版
2. 正常安装即可

**第二步：安装 Ollama + DeepSeek-R1**

```bash
# 1. 下载安装 Ollama
# 2. 打开终端运行：
ollama list  # 查看已安装模型

# 3. 下载 deepseek-r1:1.5b
ollama pull deepseek-r1:1.5b
```

**第三步：CodeGPT 插件配置**

1. PyCharm → File → Settings → Plugins → 搜索 CodeGPT 安装
2. Tools → CodeGPT → Providers
3. 选择 **Ollama(Local)**
4. 模型选择：**deepseek-r1:1.5b**
5. 点击 OK 保存

### 使用效果

- 位置：PyCharm 右侧边栏 CodeGPT 面板
- 响应速度：**1-2 秒**（Pro M1 实测）
- 费用：**完全免费**，使用本地算力
- Token 计数：插件显示 Token 使用统计，不收费

## 关键概念

- Ollama：本地大模型管理和运行工具，一条命令安装和运行模型
- CodeGPT：目前大模型 + 编程 UI 体验最好的插件之一
- DeepSeek-R1 七个版本：从 1.5b 到 70b，参数越大质量越高但电脑要求越高
- 本地推理：所有计算在本地运行，不上传代码到云端

## 相关页面

- DeepSeek
- DeepSeek VSCode 集成
- AI 编程工具对比
