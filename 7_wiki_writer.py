"""
Wiki 文章生成器 - 使用 Claude Skill 的 Agentic 工作方式 
目的是展示：claude_agent_sdk 调用 claude agent 使用 llm-wiki

核心原理：
- 不需要手动指定调用流程
- 只需配置 setting_sources 和 allowed_tools
- Claude 会根据用户输入语义自主判断并调用 llm-wiki-skill
- Skill 的触发由底层大模型自动处理

使用方法：
1. 确保 .claude/skills/llm-wiki-skill/SKILL.md 存在
2. 运行脚本，直接描述你的需求
3. Claude 会自动识别并调用 wiki skill 来处理
"""

from claude_agent_sdk import ClaudeSDKClient, ClaudeAgentOptions
from rich import print
from rich.console import Console
from rich.panel import Panel
from rich.markdown import Markdown
from dotenv import load_dotenv
import os
import argparse

# 强制从 .env 文件加载，覆盖系统环境变量
load_dotenv(override=True)

# 默认模型
DEFAULT_MODEL = os.getenv("MODEL", "deepseek-chat")


async def generate_wiki_article(user_request: str, console: Console = None):
    """
    使用 Agentic 方式生成 wiki 文章

    关键：不需要手动调用 skill，只需描述需求，
    Claude 会自动识别并调用 llm-wiki-skill
    """
    if console is None:
        console = Console()

    # 配置选项 - 关键配置：
    # 1. setting_sources=["project"] - 启用项目级 skill 扫描
    # 2. allowed_tools 包含 "Skill" - 允许模型调用 skill
    # 3. permission_mode="acceptEdits" - 自动接受编辑权限，不询问用户
    # 4. cwd - 设置工作目录为 wiki 文件夹，让 skill 能正确找到 .wiki-schema.md

    # 获取 wiki 目录路径（相对于当前脚本位置）
    script_dir = os.path.dirname(os.path.abspath(__file__))
    wiki_dir = os.path.join(script_dir, "ai-wiki")

    # 确保 wiki 目录存在
    if not os.path.exists(wiki_dir):
        console.print(Panel(
            f"❌ 错误：找不到 wiki 目录: {wiki_dir}",
            title="Error",
            border_style="red"
        ))
        return ""

    options = ClaudeAgentOptions(
        model=DEFAULT_MODEL,
        permission_mode="acceptEdits",  # 关键：自动接受所有编辑操作，不询问用户
        setting_sources=["project"],  # 关键：启用项目级设置扫描
        allowed_tools=["Skill", "Read", "Write", "Glob", "Grep", "Bash", "Edit"],  # 关键：允许调用 Skill 和 Edit
        cwd=wiki_dir,  # 关键：设置工作目录为 wiki 文件夹，skill 会在这里查找 .wiki-schema.md
        env={
            "ANTHROPIC_AUTH_TOKEN": os.getenv("ANTHROPIC_AUTH_TOKEN"),
            "ANTHROPIC_BASE_URL": os.getenv("ANTHROPIC_BASE_URL", "https://api.anthropic.com"),
        }
    )

    console.print(Panel(
        f"🚀 Wiki 文章生成器\n"
        f"使用模型: {DEFAULT_MODEL}\n"
        f"工作方式: Agentic (自动调用 Skill)",
        title="System Message",
        border_style="blue"
    ))

    console.print(Panel(
        f"用户请求: {user_request}",
        title="User Request",
        border_style="green"
    ))

    console.print("\n🤖 Claude 正在分析请求并决定如何调用 Skill...\n")

    # 直接发送用户请求，让 Claude 自主决定如何调用 skill
    # 不需要指定 "调用 llm-wiki-skill"，Claude 会根据语义自动识别
    async with ClaudeSDKClient(options=options) as client:
        await client.query(user_request)

        full_response = []
        async for message in client.receive_response():
            if hasattr(message, 'content'):
                for block in message.content:
                    if hasattr(block, 'text'):
                        text = block.text
                        full_response.append(text)
                        console.print(text, end="")
                    elif hasattr(block, 'tool_use'):
                        # 显示工具调用信息
                        tool_name = block.tool_use.name
                        console.print(f"\n[dim]🔧 调用工具: {tool_name}[/dim]\n")
                    elif hasattr(block, 'tool_result'):
                        # 显示工具结果
                        console.print(f"\n[dim]✅ 工具执行完成[/dim]\n")

        return "".join(full_response)


async def interactive_mode():
    """交互式模式"""
    console = Console()

    console.print(Panel(
        "🎉 欢迎使用 Wiki 文章生成器 (Agentic 模式)\n\n"
        "直接描述你的需求，例如:\n"
        "  • '帮我写一篇关于乐高建筑技巧的综合文章'\n"
        "  • '分析 wiki 中关于 MOC 创作的内容，生成一份报告'\n"
        "  • '基于知识库中的实体，总结乐高搭建技法'\n"
        "  • 'exit' 退出",
        title="System Message",
        border_style="blue"
    ))

    while True:
        console.print("\n" + "─" * 60)
        user_input = console.input("[bold green]你的请求 > [/bold green]").strip()

        if user_input.lower() in ["exit", "quit", "退出"]:
            console.print(Panel("👋 再见！", title="System Message", border_style="blue"))
            break

        if not user_input:
            continue

        try:
            # 直接传递用户输入，让 Claude 自主处理
            await generate_wiki_article(user_input, console)
            console.print("\n")
        except Exception as e:
            console.print(Panel(
                f"❌ 发生错误: {e}",
                title="Error",
                border_style="red"
            ))


async def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description="Wiki 文章生成器 - 使用 Claude Skill 的 Agentic 工作方式"
    )
    parser.add_argument(
        "--request", "-r",
        help="你的请求描述（例如：'帮我写一篇关于乐高建筑技巧的文章'）"
    )
    parser.add_argument(
        "--interactive", "-i",
        action="store_true",
        help="进入交互式模式"
    )

    args = parser.parse_args()

    console = Console()

    if args.interactive or not args.request:
        # 交互式模式
        await interactive_mode()
    else:
        # 命令行模式 - 直接传递用户请求
        await generate_wiki_article(args.request, console)


if __name__ == "__main__":
    import asyncio
    import nest_asyncio
    nest_asyncio.apply()

    asyncio.run(main())
