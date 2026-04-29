"""
Wiki 文章生成器 API - 基于 FastAPI 的 HTTP 服务
目的是展示：claude_agent_sdk 调用 claude agent 使用 llm-wiki ,提供api接口对外访问服务

基于 7_wiki_writer.py 功能封装的 FastAPI API 接口
支持 SSE 流式响应和非流式响应两种模式

启动命令:
    uvicorn wiki_writer_api:app --host 0.0.0.0 --port 8000 --reload

API 端点:
    POST /api/v1/wiki/generate      - 生成 wiki 文章 (SSE 流式)
    POST /api/v1/wiki/generate/sync - 生成 wiki 文章 (同步非流式)
    GET  /health                    - 健康检查
"""

import asyncio
import json
import os
from typing import Optional, AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from dotenv import load_dotenv

from claude_agent_sdk import ClaudeSDKClient, ClaudeAgentOptions

# 强制从 .env 文件加载，覆盖系统环境变量
load_dotenv(override=True)

# 默认模型
DEFAULT_MODEL = os.getenv("MODEL", "deepseek-chat")

# 获取 wiki 目录路径
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
WIKI_DIR = os.path.join(SCRIPT_DIR, "ai-wiki")


# ============ Pydantic 模型 ============

class WikiGenerateRequest(BaseModel):
    """Wiki 文章生成请求模型"""
    request: str = Field(..., description="用户请求描述，例如：'帮我写一篇关于乐高建筑技巧的文章'")
    model: Optional[str] = Field(default=None, description="使用的模型，默认使用环境变量 MODEL 或 deepseek-chat")
    permission_mode: str = Field(default="acceptEdits", description="权限模式: acceptEdits/askUser/bypassPermissions")
    stream: bool = Field(default=True, description="是否使用流式响应 (SSE)")


class WikiGenerateResponse(BaseModel):
    """Wiki 文章生成响应模型 (非流式)"""
    success: bool
    content: str
    model: str
    request: str


class HealthResponse(BaseModel):
    """健康检查响应模型"""
    status: str
    wiki_dir_exists: bool
    wiki_dir_path: str
    default_model: str


class ErrorResponse(BaseModel):
    """错误响应模型"""
    error: str
    detail: Optional[str] = None


# ============ 生命周期管理 ============

@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    # 启动时检查
    if not os.path.exists(WIKI_DIR):
        print(f"⚠️ 警告：wiki 目录不存在: {WIKI_DIR}")
    else:
        print(f"✅ wiki 目录已加载: {WIKI_DIR}")
    yield
    # 关闭时清理
    print("👋 API 服务已关闭")


# ============ FastAPI 应用实例 ============

app = FastAPI(
    title="Wiki 文章生成器 API",
    description="基于 Claude Agent SDK 的 Wiki 文章生成服务，支持 Agentic 工作方式和 Skill 自动调用",
    version="1.0.0",
    lifespan=lifespan
)

# 配置 CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境应限制具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============ 核心服务函数 ============

async def generate_wiki_article_stream(
    user_request: str,
    model: Optional[str] = None,
    permission_mode: str = "acceptEdits"
) -> AsyncGenerator[str, None]:
    """
    流式生成 wiki 文章
    
    生成 SSE 格式的数据流，每个数据块包含:
    - type: 消息类型 (text/tool_use/tool_result/done/error)
    - data: 具体数据内容
    """
    if not os.path.exists(WIKI_DIR):
        yield f"data: {json.dumps({'type': 'error', 'data': f'wiki 目录不存在: {WIKI_DIR}'}, ensure_ascii=False)}\n\n"
        return

    use_model = model or DEFAULT_MODEL
    
    # 发送开始事件
    yield f"data: {json.dumps({'type': 'start', 'data': {'model': use_model, 'request': user_request}}, ensure_ascii=False)}\n\n"
    
    options = ClaudeAgentOptions(
        model=use_model,
        permission_mode=permission_mode,
        setting_sources=["project"],
        allowed_tools=["Skill", "Read", "Write", "Glob", "Grep", "Bash", "Edit"],
        cwd=WIKI_DIR,
        env={
            "ANTHROPIC_AUTH_TOKEN": os.getenv("ANTHROPIC_AUTH_TOKEN"),
            "ANTHROPIC_BASE_URL": os.getenv("ANTHROPIC_BASE_URL", "https://api.anthropic.com"),
        }
    )
    
    try:
        async with ClaudeSDKClient(options=options) as client:
            await client.query(user_request)
            
            async for message in client.receive_response():
                if hasattr(message, 'content'):
                    for block in message.content:
                        if hasattr(block, 'text'):
                            # 文本内容
                            text = block.text
                            yield f"data: {json.dumps({'type': 'text', 'data': text}, ensure_ascii=False)}\n\n"
                        
                        elif hasattr(block, 'tool_use'):
                            # 工具调用
                            tool_name = block.tool_use.name
                            tool_input = getattr(block.tool_use, 'input', {})
                            yield f"data: {json.dumps({'type': 'tool_use', 'data': {'name': tool_name, 'input': tool_input}}, ensure_ascii=False)}\n\n"
                        
                        elif hasattr(block, 'tool_result'):
                            # 工具执行结果
                            tool_result = getattr(block, 'tool_result', {})
                            yield f"data: {json.dumps({'type': 'tool_result', 'data': str(tool_result)}, ensure_ascii=False)}\n\n"
            
            # 发送完成事件
            yield f"data: {json.dumps({'type': 'done', 'data': '生成完成'}, ensure_ascii=False)}\n\n"
            
    except Exception as e:
        error_msg = str(e)
        yield f"data: {json.dumps({'type': 'error', 'data': error_msg}, ensure_ascii=False)}\n\n"


async def generate_wiki_article_sync(
    user_request: str,
    model: Optional[str] = None,
    permission_mode: str = "acceptEdits"
) -> dict:
    """
    同步生成 wiki 文章
    
    返回完整的生成结果，适用于不需要实时流式展示的场景
    """
    if not os.path.exists(WIKI_DIR):
        raise HTTPException(
            status_code=500,
            detail=f"wiki 目录不存在: {WIKI_DIR}"
        )

    use_model = model or DEFAULT_MODEL
    full_response = []
    tool_calls = []
    
    options = ClaudeAgentOptions(
        model=use_model,
        permission_mode=permission_mode,
        setting_sources=["project"],
        allowed_tools=["Skill", "Read", "Write", "Glob", "Grep", "Bash", "Edit"],
        cwd=WIKI_DIR,
        env={
            "ANTHROPIC_AUTH_TOKEN": os.getenv("ANTHROPIC_AUTH_TOKEN"),
            "ANTHROPIC_BASE_URL": os.getenv("ANTHROPIC_BASE_URL", "https://api.anthropic.com"),
        }
    )
    
    try:
        async with ClaudeSDKClient(options=options) as client:
            await client.query(user_request)
            
            async for message in client.receive_response():
                if hasattr(message, 'content'):
                    for block in message.content:
                        if hasattr(block, 'text'):
                            full_response.append(block.text)
                        
                        elif hasattr(block, 'tool_use'):
                            tool_calls.append({
                                'type': 'tool_use',
                                'name': block.tool_use.name,
                                'input': getattr(block.tool_use, 'input', {})
                            })
                        
                        elif hasattr(block, 'tool_result'):
                            tool_calls.append({
                                'type': 'tool_result',
                                'result': str(getattr(block, 'tool_result', {}))
                            })
        
        return {
            "success": True,
            "content": "".join(full_response),
            "model": use_model,
            "request": user_request,
            "tool_calls": tool_calls
        }
        
    except Exception as e:
        import traceback
        error_detail = f"生成失败: {str(e)}\n{traceback.format_exc()}"
        print(error_detail)  # 打印到服务器日志
        raise HTTPException(
            status_code=500,
            detail=error_detail
        )


# ============ API 路由 ============

@app.get("/", response_model=dict)
async def root():
    """根路径 - API 信息"""
    return {
        "name": "Wiki 文章生成器 API",
        "version": "1.0.0",
        "description": "基于 Claude Agent SDK 的 Wiki 文章生成服务",
        "endpoints": {
            "health": "/health",
            "generate_stream": "/api/v1/wiki/generate (POST, SSE)",
            "generate_sync": "/api/v1/wiki/generate/sync (POST, JSON)"
        }
    }


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """健康检查端点"""
    return HealthResponse(
        status="healthy",
        wiki_dir_exists=os.path.exists(WIKI_DIR),
        wiki_dir_path=WIKI_DIR,
        default_model=DEFAULT_MODEL
    )


@app.post("/api/v1/wiki/generate")
async def generate_wiki(request: WikiGenerateRequest):
    """
    生成 Wiki 文章 (SSE 流式响应)
    
    使用 Server-Sent Events 流式返回生成过程，适合需要实时展示生成进度的场景。
    
    请求示例:
    ```json
    {
        "request": "帮我写一篇关于乐高建筑技巧的文章",
        "model": "deepseek-chat",
        "permission_mode": "acceptEdits",
        "stream": true
    }
    ```
    
    SSE 事件类型:
    - start: 开始生成
    - text: 文本内容片段
    - tool_use: 工具调用信息
    - tool_result: 工具执行结果
    - done: 生成完成
    - error: 错误信息
    """
    if request.stream:
        return StreamingResponse(
            generate_wiki_article_stream(
                user_request=request.request,
                model=request.model,
                permission_mode=request.permission_mode
            ),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no"  # 禁用 Nginx 缓冲
            }
        )
    else:
        # 非流式模式，直接返回 JSON
        result = await generate_wiki_article_sync(
            user_request=request.request,
            model=request.model,
            permission_mode=request.permission_mode
        )
        return JSONResponse(content=result)


@app.post("/api/v1/wiki/generate/sync", response_model=WikiGenerateResponse)
async def generate_wiki_sync(request: WikiGenerateRequest):
    """
    生成 Wiki 文章 (同步非流式响应)
    
    直接返回完整的生成结果，适合不需要实时流式展示的场景。
    
    请求示例:
    ```json
    {
        "request": "帮我写一篇关于乐高建筑技巧的文章",
        "model": "deepseek-chat",
        "permission_mode": "acceptEdits"
    }
    ```
    """
    result = await generate_wiki_article_sync(
        user_request=request.request,
        model=request.model,
        permission_mode=request.permission_mode
    )
    return WikiGenerateResponse(**result)


# ============ 主入口 ============

if __name__ == "__main__":
    import uvicorn
    import nest_asyncio
    nest_asyncio.apply()
    
    print("🚀 启动 Wiki 文章生成器 API 服务...")
    print(f"📁 Wiki 目录: {WIKI_DIR}")
    print(f"🤖 默认模型: {DEFAULT_MODEL}")
    print("\nAPI 端点:")
    print("  • GET  /health                    - 健康检查")
    print("  • POST /api/v1/wiki/generate      - 流式生成 (SSE)")
    print("  • POST /api/v1/wiki/generate/sync - 同步生成 (JSON)")
    print("\n启动命令: uvicorn wiki_writer_api:app --host 0.0.0.0 --port 8000 --reload")
    
    uvicorn.run(
        "wiki_writer_api:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
