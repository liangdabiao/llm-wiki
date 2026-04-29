---
source_url: https://mp.weixin.qq.com/s/QUaAO5BEUpv5pXsHz9T1fw
source_type: article
ingest_date: 2026-04-29
---

# DeepSeek接入Python，一般电脑也能飞速跑，确实可以封神了！

## 核心方案

DeepSeek-r1:1.5b + PyCharm社区版 + CodeGPT插件 = 零成本，本地1-2秒响应

## 选型原因

1. 本地大模型好处：个人知识库管理、编程学习辅助
2. DeepSeek-R1：7个版本，参数越大对电脑要求越高
3. 推荐1.5b版本，普通电脑无GPU也能流畅运行
4. 解决了小模型回复Token短、质量低的问题

## 详细搭建步骤

### 第一步：安装PyCharm社区版（免费）

### 第二步：安装Ollama + deepseek-r1:1.5b

```bash
# 安装Ollama后运行
ollama list  # 查看已安装模型
ollama pull deepseek-r1:1.5b  # 下载模型
```

### 第三步：接入PyCharm

1. 下载安装 CodeGPT插件
2. 文件-设置-插件-搜索CodeGPT，安装
3. 工具-Tools-CodeGPT-Providers
4. 选择 Ollama(Local)
5. 选择 deepseek-r1:1.5b

## 效果

- 右侧直接对话，1-2秒响应
- Pro-M1实测快速响应
- 使用本地算力，免费无费用
- CodeGPT是目前大模型+编程UI最好用的插件之一
