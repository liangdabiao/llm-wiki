---
source_url: https://mp.weixin.qq.com/s/g6E-gNHZABMl6JUEWQtViQ
source_type: wechat
ingest_date: 2026-04-29
---

## 手把手教你在word中接入deepseek，秒生文档材料

将DeepSeek接入Word，实现无需切换即可进行材料续写的功能，具有显著的价值和广泛的应用前景。

### 核心价值

1. **提升工作效率**：无需频繁切换应用，减少操作步骤和时间成本
2. **无缝衔接创作流程**：同一界面完成从构思到成稿的全过程
3. **智能辅助与内容优化**：语法修正、风格优化、逻辑完善
4. **降低创作门槛**：根据关键词自动生成高质量草稿
5. **个性化定制与学习能力**：学习并适应用户写作风格
6. **多场景适用性**：学术、商业、日常办公全覆盖
7. **数据安全与隐私保护**：不经过第三方平台
8. **未来扩展潜力**：多语言翻译、自动生成图表、智能排版

### 01 获取 API_KEY

1. 登录 www.deepseek.com，注册后点击左上角"API 开放平台"
2. 充值后点击左侧"API keys"
3. 创建 API key，复制备用

### 02 添加 VBA 脚本

1. 开发工具中添加 VB 脚本（无开发工具：文件-选项-自定义功能区设置）
2. 在 Normal 的模块下右键新增模块，输入代码后保存
3. 将代码中的"你的APIKEY"替换为实际 Key

```vbnet
Function CallDeepSeekAPI(api_key As String, inputText As String)
    Dim API As String
    Dim SendTxt As String
    Dim Http As Object
    Dim status_code As Integer
    Dim response As String
    API = "https://api.deepseek.com/chat/completions"
    SendTxt = "{""model"": ""deepseek-chat"", ""messages"": 
[{""role"":""system"", ""content"":""你是word文案助手""}, 
{""role"":""user"", ""content"":""" & inputText & """}], 
""stream"": false}"
    Set Http = CreateObject("MSXML2.XMLHTTP")
    With Http
    .Open "POST", API, False
    .setRequestHeader "Content-Type", "application/json"
    .setRequestHeader "Authorization", "Bearer " & api_key
    .send SendTxt
    status_code = .Status
    response = .responseText
   End With
   
If status_code = 200 Then
    CallDeepSeekAPI = response
    Else
      CallDeepSeekAPI = "Error: " & status_code & " - " & response
 End If
    Set Http = Nothing
End Function

Sub DeepSeekV3()
    Dim api_key As String
    Dim inputText As String
    Dim response As String
    Dim regex As Object
    Dim matches As Object
    Dim originalSelection As Object
    api_key = "你的APIKEY"
    If api_key = "" Then
       MsgBox "Please enter the API key."
      Exit Sub
    ElseIf Selection.Type <> wdSelectionNormal Then
       MsgBox "请选择文本."
     Exit Sub
  End If
   ' 保存原始选中的文本
  Set originalSelection = Selection.Range.Duplicate
   inputText = Replace(Replace(Replace(Replace(Replace(Selection.Text, 
"\", "\\"), vbCrLf, ""), vbCr, ""), vbLf, ""), Chr(34), "\""")
   response = CallDeepSeekAPI(api_key, inputText)
   ' ... 解析响应并插入内容
End Sub
```

（完整代码见原文，包含 deepseek-chat 和 deepseek-reasoner 两个模型调用）

### 03 功能配置

1. 打开菜单文件-选项-自定义功能区
2. 将宏添加到工具栏，设置按钮图标

### 04 功能测试

1. 新建文档，输入内容，选择文字后点击"对话"
2. 自动在下方插入 AI 生成内容
