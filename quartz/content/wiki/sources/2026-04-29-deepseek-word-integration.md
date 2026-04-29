---
tags: [DeepSeek, Word, VBA, API, 办公自动化]
created: 2026-04-29
updated: 2026-04-29
source_path: raw/articles/2026-04-29-deepseek-word-integration.md
---

# DeepSeek Word 集成教程：VBA 脚本一键接入，秒生文档材料

> 手把手教你通过 VBA 将 DeepSeek API 接入 Word，实现无需切换界面的智能续写，附完整可运行代码

## 核心观点

1. **八大核心价值显著**：提升效率、无缝衔接创作、智能辅助优化、降低创作门槛、个性化学习、多场景适用、数据安全保障、未来扩展潜力巨大

2. **双模型支持**：同时接入 `deepseek-chat`（普通创作）和 `deepseek-reasoner`（深度推理）两个模型，按需切换

3. **原生集成体验**：选中文本后点击按钮，AI 自动生成内容插入下方，完全在 Word 界面内完成，无需切换应用

4. **代码由 DeepSeek 自生成**：整个集成方案的 VBA 代码都是由 DeepSeek 自动生成的，演示了 AI 自我迭代的能力

## 实操内容保留

### 完整集成三步法

**Step 1 获取 API_KEY**：
1. 登录 www.deepseek.com
2. 点击左上角"API 开放平台"
3. 充值后点击左侧"API keys"
4. 创建 API Key 并复制备用

**Step 2 添加 VBA 脚本**：
1. 打开开发工具（没有的话：文件→选项→自定义功能区）
2. Normal 模块下右键→新增模块
3. 粘贴完整 VBA 代码
4. 将代码中的"你的APIKEY"替换为实际 Key

**核心代码片段**：
```vbnet
' API 调用函数（支持双模型）
Function CallDeepSeekAPI(api_key, inputText)
    API = "https://api.deepseek.com/chat/completions"
    SendTxt = "{""model"": ""deepseek-chat"", ""messages"": ...}"
    ' ... 完整 HTTP 请求
End Function

' 主调用函数
Sub DeepSeekV3()
    api_key = "你的APIKEY"
    inputText = Selection.Text  ' 获取选中文本
    response = CallDeepSeekAPI(api_key, inputText)
    ' ... 解析 JSON 并插入到光标下一行
End Sub
```

**Step 3 功能配置与测试**：
1. 文件→选项→自定义功能区，将宏添加到工具栏
2. 新建文档→输入内容→选中文字→点击"对话"
3. 自动在下方插入 AI 生成内容

### 八大核心价值详解

| 价值 | 具体说明 |
|------|---------|
| 提升工作效率 | 无需频繁切换应用，减少操作步骤 |
| 无缝创作流程 | 同一界面完成从构思到成稿 |
| 智能辅助优化 | 语法修正、风格优化、逻辑完善 |
| 降低创作门槛 | 关键词自动生成高质量草稿 |
| 个性化学习 | 学习并适应用户写作风格 |
| 多场景适用 | 学术、商业、日常办公全覆盖 |
| 数据安全保障 | 不经过第三方平台 |
| 未来扩展潜力 | 多语言翻译、图表生成、智能排版 |

## 关键概念

- Office VBA + AI API 集成模式
- 本地文档 + 云端大模型混合架构
- 双模型按需切换策略
- 文本选中→API 调用→结果插入的交互范式

## 相关页面

- DeepSeek
- AI 办公自动化
