#!/bin/bash
#==============================================================================
# llm-wiki 质量检查脚本
# 功能：自动检查知识库的常见质量问题
#
# 使用方式：
#   bash lint-wiki.sh <知识库路径> [检查项]
#   检查项可选：links, sources, content, depth, all（默认 all）
#
# 示例：
#   bash lint-wiki.sh ./my-wiki all
#   bash lint-wiki.sh ./my-wiki links sources
#==============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查参数
if [ -z "$1" ]; then
    echo "使用方式: $0 <知识库路径> [检查项]"
    echo "检查项: links, sources, content, depth, all（默认）"
    exit 1
fi

WIKI_PATH="$1"
shift
CHECK_ITEMS="$@"

if [ -z "$CHECK_ITEMS" ]; then
    CHECK_ITEMS="all"
fi

# 切换到知识库目录
cd "$WIKI_PATH" || { echo "错误: 无法进入目录 $WIKI_PATH"; exit 1; }

# 初始化计数器
ERROR_COUNT=0
WARNING_COUNT=0
PASS_COUNT=0

echo "========================================"
echo "  llm-wiki 质量检查"
echo "  检查路径: $WIKI_PATH"
echo "  检查项: $CHECK_ITEMS"
echo "========================================"

# 检查是否安装了 yq
if ! command -v yq &> /dev/null; then
    echo -e "${YELLOW}警告: 未安装 yq，无法检查 YAML 语法。${NC}"
    echo "请安装 yq: https://github.com/mikefarah/yq"
fi
echo ""

#==============================================================================
# 检查项 1: 链接完整性（断链检查）
#==============================================================================
check_links() {
    echo "[检查 1/5] 链接完整性..."
    echo "----------------------------------------"

    local has_error=0

    # 提取所有 [[链接]] - 排除 frontmatter（--- 之间的内容）和代码块
    # 使用更精确的匹配，只匹配真正的 wikilink 语法
    ALL_LINKS=$(grep -roh '\[\[[^]]*\]\]' --include="*.md" wiki/ index.md log.md 2>/dev/null | \
        sort -u | \
        sed 's/\[\[//;s/\]\]//' | \
        grep -v "^[0-9]\{4\}-" | \ # 排除纯日期模式（可能是误匹配）
        grep -v "^[A-Z]$" | \ # 排除单字母
        grep -v "^[0-9]$" | \ # 排除单数字
        cat)

    for link in $ALL_LINKS; do
        # 检查对应的 .md 文件是否存在
        if [ ! -f "wiki/entities/${link}.md" ] && \
           [ ! -f "wiki/topics/${link}.md" ] && \
           [ ! -f "wiki/sources/${link}.md" ] && \
           [ ! -f "wiki/comparisons/${link}.md" ] && \
           [ ! -f "wiki/synthesis/${link}.md" ] && \
           [ ! -f "${link}.md" ]; then
            echo -e "${RED}❌ 断链: [[${link}]]${NC}"
            # 显示哪些文件引用了这个断链
            echo "   引用位置:"
            grep -rl "\[\[${link}\]\]" --include="*.md" . | head -3 | sed 's/^/      - /'
            has_error=1
            ERROR_COUNT=$((ERROR_COUNT + 1))
        fi
    done

    if [ $has_error -eq 0 ]; then
        echo -e "${GREEN}✅ 所有链接有效${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
    echo ""
}

#==============================================================================
# 检查项 2: sources 字段完整性
#==============================================================================
check_sources() {
    echo "[检查 2/5] sources 字段完整性..."
    echo "----------------------------------------"

    local has_error=0

    # 检查实体页
    for f in wiki/entities/*.md; do
        if [ ! -f "$f" ]; then continue; fi

        # 检查 frontmatter 中的 sources 字段
        sources_line=$(head -10 "$f" | grep "^sources:")

        if [ -z "$sources_line" ]; then
            echo -e "${YELLOW}⚠️  缺少 sources 字段: $f${NC}"
            WARNING_COUNT=$((WARNING_COUNT + 1))
            has_error=1
        elif echo "$sources_line" | grep -q "sources:\s*\[\]"; then
            echo -e "${RED}❌ sources 为空: $f${NC}"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            has_error=1
        elif echo "$sources_line" | grep -q "FIRST_SOURCE"; then
            echo -e "${RED}❌ sources 包含模板占位符: $f${NC}"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            has_error=1
        fi
    done

    # 检查主题页
    for f in wiki/topics/*.md; do
        if [ ! -f "$f" ]; then continue; fi

        sources_line=$(head -10 "$f" | grep "^sources:")

        if [ -z "$sources_line" ]; then
            echo -e "${YELLOW}⚠️  缺少 sources 字段: $f${NC}"
            WARNING_COUNT=$((WARNING_COUNT + 1))
            has_error=1
        elif echo "$sources_line" | grep -q "sources:\s*\[\]"; then
            echo -e "${RED}❌ sources 为空: $f${NC}"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            has_error=1
        elif echo "$sources_line" | grep -q "FIRST_SOURCE"; then
            echo -e "${RED}❌ sources 包含模板占位符: $f${NC}"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            has_error=1
        fi
    done

    if [ $has_error -eq 0 ]; then
        echo -e "${GREEN}✅ 所有实体页和主题页 sources 字段已正确填写${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
    echo ""
}

#==============================================================================
# 检查项 3: 内容必填节检查
#==============================================================================
check_content() {
    echo "[检查 3/5] 内容必填节检查..."
    echo "----------------------------------------"

    local has_error=0

    # 检查素材摘要页
    for f in wiki/sources/*.md; do
        if [ ! -f "$f" ]; then continue; fi

        # 跳过短内容（简化处理的素材）
        content_length=$(wc -c < "$f")
        if [ $content_length -lt 1000 ]; then
            continue
        fi

        # 检查实操内容保留
        if ! grep -q "实操内容" "$f"; then
            echo -e "${YELLOW}⚠️  缺少实操内容节: $f${NC}"
            WARNING_COUNT=$((WARNING_COUNT + 1))
            has_error=1
        fi

        # 检查原文精彩摘录
        if ! grep -q "原文精彩摘录" "$f"; then
            echo -e "${YELLOW}⚠️  缺少原文精彩摘录节: $f${NC}"
            WARNING_COUNT=$((WARNING_COUNT + 1))
            has_error=1
        fi
    done

    if [ $has_error -eq 0 ]; then
        echo -e "${GREEN}✅ 所有长素材摘要包含必填节${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
    echo ""
}

#==============================================================================
# 检查项 4: 内容深度（最低字数）
#==============================================================================
check_depth() {
    echo "[检查 4/5] 内容深度检查..."
    echo "----------------------------------------"

    local has_error=0
    local MIN_CHARS=1500

    for f in wiki/entities/*.md; do
        if [ ! -f "$f" ]; then continue; fi

        # 计算正文长度（排除 frontmatter 和 相关页面节）
        # 简化计算：全文长度减去 500（frontmatter 估算）
        total_chars=$(wc -c < "$f")
        content_chars=$((total_chars - 500))

        if [ $content_chars -lt $MIN_CHARS ]; then
            echo -e "${YELLOW}⚠️  内容过短（${content_chars}字符，建议最少 ${MIN_CHARS}）: $f${NC}"
            WARNING_COUNT=$((WARNING_COUNT + 1))
            has_error=1
        fi
    done

    if [ $has_error -eq 0 ]; then
        echo -e "${GREEN}✅ 所有实体页内容深度达标${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
    echo ""
}

#==============================================================================
# 检查项 5: index.md 完整性
#==============================================================================
check_index() {
    echo "[检查 5/5] index.md 完整性..."
    echo "----------------------------------------"

    local has_error=0

    # 统计实际文件数
    actual_sources=$(ls -1 wiki/sources/*.md 2>/dev/null | wc -l)
    actual_entities=$(ls -1 wiki/entities/*.md 2>/dev/null | wc -l)
    actual_topics=$(ls -1 wiki/topics/*.md 2>/dev/null | wc -l)

    # 检查 index.md 中的统计
    index_sources=$(grep -o "素材总数：[0-9]*" index.md | grep -o "[0-9]*" || echo "0")

    if [ -n "$index_sources" ] && [ "$index_sources" != "$actual_sources" ]; then
        echo -e "${YELLOW}⚠️  素材数统计不一致: index.md 说 ${index_sources}，实际 ${actual_sources}${NC}"
        WARNING_COUNT=$((WARNING_COUNT + 1))
        has_error=1
    fi

    # 检查文件是否都在 index 中有记录
    for f in wiki/sources/*.md wiki/entities/*.md wiki/topics/*.md; do
        if [ ! -f "$f" ]; then continue; fi
        filename=$(basename "$f" .md)
        if ! grep -q "\[\[${filename}\]\]" index.md; then
            echo -e "${YELLOW}⚠️  文件未在 index.md 中索引: $f${NC}"
            WARNING_COUNT=$((WARNING_COUNT + 1))
            has_error=1
        fi
    done

    if [ $has_error -eq 0 ]; then
        echo -e "${GREEN}✅ index.md 完整性达标${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
    echo ""
}

#==============================================================================
# 执行检查
#==============================================================================
case "$CHECK_ITEMS" in
    all|ALL)
        check_links
        check_sources
        check_content
        check_depth
        check_index
        ;;
    *)
        for item in $CHECK_ITEMS; do
            case "$item" in
                links) check_links ;;
                sources) check_sources ;;
                content) check_content ;;
                depth) check_depth ;;
                *) echo "未知检查项: $item" ;;
            esac
        done
        ;;
esac

#==============================================================================
# 汇总报告
#==============================================================================
echo "========================================"
echo "  检查结果汇总"
echo "========================================"
echo -e "  通过: ${GREEN}${PASS_COUNT}${NC} 项"
echo -e "  警告: ${YELLOW}${WARNING_COUNT}${NC} 项"
echo -e "  错误: ${RED}${ERROR_COUNT}${NC} 项"
echo ""

if [ $ERROR_COUNT -gt 0 ]; then
    echo -e "${RED}❌ 发现需要修复的错误，请处理后重新检查${NC}"
    exit 1
elif [ $WARNING_COUNT -gt 0 ]; then
    echo -e "${YELLOW}⚠️  发现一些可以改进的地方，建议优化${NC}"
    exit 0
else
    echo -e "${GREEN}✅ 所有质量检查通过！${NC}"
    exit 0
fi
