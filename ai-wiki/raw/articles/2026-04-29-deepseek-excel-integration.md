---
source_url: https://mp.weixin.qq.com/s/ZD6KRtYPr7gpsPtAiwiLvQ
source_type: wechat
ingest_date: 2026-04-29
---

## DeepSeek嵌入到Excel，提升10倍工作效率，太牛了！

借助VBA代码实现DeepSeek嵌入Excel，以下代码都是由DeepSeek自动生成的，实现在A1单元格输入数据，点击按钮执行，在B1单元格输出结果。

### 一、获取 API

1. 官网右上角点击【API开放平台】
2. 右侧找到【API keys】
3. 设置名称，复制 API Key 备用

### 二、插入 VBA 代码

1. 打开 Excel，按下快捷键 `ALT+F11` 调出 VBA 编辑窗口
2. 左侧空白区域点击，【插入】→ 【模块】
3. 将下面代码粘贴到窗口中
4. 将【你的API】替换为刚才获取的 API 地址

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
    
    ' 设置 API 的 URL 和 API 密钥
    url = "https://api.deepseek.com/v1/chat/completions"
    apiKey = "你的API" ' 替换为你的 API 密钥
    
    ' 创建 HTTP 请求对象
    Set http = CreateObject("MSXML2.XMLHTTP")
    
    ' 设置请求头
    http.Open "POST", url, False
    http.setRequestHeader "Content-Type", "application/json"
    http.setRequestHeader "Authorization", "Bearer " & apiKey
    
    ' 设置请求体
    Dim requestBody As String
    requestBody = "{""model"":""deepseek-chat"",""messages"":
[{""role"":""user"",""content"":""" & question & """}]}"
    
    ' 发送请求
    http.send requestBody
    
    ' 获取响应
    If http.Status = 200 Then
        response = http.responseText
        
        ' 从 JSON 字符串中提取 content 字段
        startPos = InStr(response, """content"":""") + 
Len("""content"":""")
        endPos = InStr(startPos, response, """")
        content = Mid(response, startPos, endPos - startPos)
        
        ' 将结果写入 A2 单元格
        ThisWorkbook.Sheets(1).Range("A2").Value = content
    Else
        ' 如果请求失败，显示错误信息
        ThisWorkbook.Sheets(1).Range("A2").Value = 
"Error: " & http.Status & " - " & http.statusText
    End If
End Sub
```

### 三、设置按钮

1. 点击【开发工具】→【插入】
2. 在表单控件中选择【按钮】
3. 新建按钮，指定给 `CallDeepSeekAPI` 这个宏

设置完毕：在 A1 单元格输入问题 → 点击【按钮】→ 等待 AI 回答出现在 A2 单元格
