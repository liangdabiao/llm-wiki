---
tags: [DeepSeek, Excel, VBA, API, 办公自动化]
created: 2026-04-29
updated: 2026-04-29
source_path: raw/articles/2026-04-29-deepseek-excel-integration.md
---

# DeepSeek Excel 集成：VBA 实现表格 AI 化，效率提升 10 倍

> 完整教程：从 API 获取到 VBA 代码粘贴再到按钮配置，三步实现 Excel 单元格提问 → AI 回答的智能化工作流

## 核心观点

1. **代码由 AI 自生成**：整个 VBA 集成代码都是由 DeepSeek 自动生成的，演示了 AI 自我赋能的能力

2. **极简交互设计**：A1 输入问题 → 点击按钮 → A2 输出答案，操作流程简单到无需学习成本

3. **效率提升数量级**：将 AI 能力直接嵌入最高频的办公工具，消除切换成本，实现"效率提升 10 倍"的数量级提升

## 实操内容保留

### 三步完整集成流程

**Step 1 获取 API**：
1. DeepSeek 官网右上角点击【API 开放平台】
2. 右侧找到【API keys】
3. 设置名称，复制 API Key 备用

**Step 2 插入 VBA 代码**：
1. 打开 Excel，按下快捷键 `ALT+F11` 调出 VBA 编辑窗口
2. 左侧空白区域点击 → 【插入】→ 【模块】
3. 将代码粘贴到窗口中
4. 将【你的API】替换为实际 API 地址

**完整 VBA 代码**：
```vbnet
Sub CallDeepSeekAPI()
    Dim question As String
    Dim response As String
    Dim url As String
    Dim apiKey As String
    Dim http As Object
    Dim content As String
    Dim startPos As Long
    Dim endPos As Long
    
    ' 获取 A1 单元格中的问题
    question = ThisWorkbook.Sheets(1).Range("A1").Value
    
    ' 设置 API
    url = "https://api.deepseek.com/v1/chat/completions"
    apiKey = "你的API"
    
    ' 创建 HTTP 请求
    Set http = CreateObject("MSXML2.XMLHTTP")
    http.Open "POST", url, False
    http.setRequestHeader "Content-Type", "application/json"
    http.setRequestHeader "Authorization", "Bearer " & apiKey
    
    ' 构建请求体
    Dim requestBody As String
    requestBody = "{""model"":""deepseek-chat"",
""messages"":[{""role"":""user"",
""content"":""" & question & """}]}"
    
    ' 发送请求
    http.send requestBody
    
    ' 解析响应
    If http.Status = 200 Then
        response = http.responseText
        startPos = InStr(response, """content"":""") + 
Len("""content"":""")
        endPos = InStr(startPos, response, """")
        content = Mid(response, startPos, endPos - startPos)
        ThisWorkbook.Sheets(1).Range("A2").Value = content
    Else
        ThisWorkbook.Sheets(1).Range("A2").Value = 
"Error: " & http.Status & " - " & http.statusText
    End If
End Sub
```

**Step 3 设置按钮**：
1. 点击【开发工具】→【插入】
2. 在表单控件中选择【按钮】
3. 新建按钮，指定给 `CallDeepSeekAPI` 宏

**最终使用方式**：
```
A1 单元格输入问题 → 点击【按钮】→ 等待 AI 回答出现在 A2 单元格
```

### 典型应用场景

| 场景 | 使用方式 | 价值 |
|------|---------|------|
| 数据解释 | A1："解释一下这个销售数据的趋势" | 快速获得洞察 |
| 公式生成 | A1："帮我写一个计算毛利率的 Excel 公式" | 不用查函数文档 |
| 数据清洗 | A1："把这列地址中的省份提取出来" | 用自然语言处理数据 |
| 报告生成 | A1："根据以上数据写一段300字的分析报告" | 一键生成文案 |
| VBA 开发 | A1："帮我写一个批量重命名工作表的宏代码" | AI 自己写代码增强自己 |

## 关键概念

- Excel VBA + AI API 集成范式
- 单元格级别的 AI 交互
- 宏按钮触发的无代码 AI 使用方式
- AI 自增强循环（AI 写代码增强 AI 自身能力）

## 扩展思路

- 支持批量处理整列数据
- 增加自定义系统提示词的配置单元格
- 支持选择模型（普通/推理）
- 增加历史对话上下文记忆
- 支持图表生成建议

## 相关页面

- DeepSeek
- AI 办公自动化
- DeepSeek Word 集成
