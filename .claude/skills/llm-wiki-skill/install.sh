#!/bin/bash
# llm-wiki unified installer
set -euo pipefail

SKILL_NAME="llm-wiki"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_REGISTRY_SCRIPT="$SCRIPT_DIR/scripts/source-registry.sh"
ADAPTER_STATE_SCRIPT="$SCRIPT_DIR/scripts/adapter-state.sh"
PLATFORM="auto"
DRY_RUN=0
TARGET_DIR=""

# 这些项目都在运行时会被读取或链接：
# - 入口与说明文件：README / CLAUDE / AGENTS / CHANGELOG
# - 安装入口：install.sh / setup.sh
# - 实际执行内容：SKILL.md / scripts / templates / deps
# - 平台薄入口：platforms（README、CLAUDE、AGENTS 都会引用）
MANAGED_ITEMS=(
  "SKILL.md"
  "README.md"
  "CLAUDE.md"
  "AGENTS.md"
  "CHANGELOG.md"
  "install.sh"
  "setup.sh"
  "scripts"
  "templates"
  "deps"
  "platforms"
)

DEP_SKILLS=()

# 微信工具 URL 从共享配置读取，与 adapter-state.sh 保持一致
source "$SCRIPT_DIR/scripts/shared-config.sh"

info()  { printf '\033[36m[信息]\033[0m %s\n' "$1"; }
ok()    { printf '\033[32m[完成]\033[0m %s\n' "$1"; }
warn()  { printf '\033[33m[警告]\033[0m %s\n' "$1"; }
err()   { printf '\033[31m[错误]\033[0m %s\n' "$1" >&2; }

usage() {
  cat <<'EOF'
用法：
  bash install.sh --platform <claude|codex|openclaw|auto> [--dry-run]

选项：
  --platform   目标平台。默认 auto；只有检测到唯一平台时才会自动安装。
  --dry-run    只打印安装计划，不写入文件。
  --target-dir 指定技能目标目录（主要给兼容入口内部调用）。
  -h, --help   显示帮助。
EOF
}

load_dependency_skills() {
  local dep

  DEP_SKILLS=()

  while IFS= read -r dep; do
    [ -n "$dep" ] && DEP_SKILLS+=("$dep")
  done < <(bash "$SOURCE_REGISTRY_SCRIPT" unique-dependencies bundled)
}

join_source_labels() {
  local category="$1"

  bash "$SOURCE_REGISTRY_SCRIPT" list-by-category "$category" \
    | awk -F '\t' '
      BEGIN { separator = "" }
      NF {
        printf "%s%s", separator, $2
        separator = "、"
      }
      END {
        if (separator == "") {
          printf "-"
        }
        printf "\n"
      }
    '
}

run_cmd() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

copy_item() {
  local source_path="$1"
  local target_path="$2"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] copy %s -> %s\n' "$source_path" "$target_path"
    return 0
  fi

  rm -rf "$target_path"
  cp -R "$source_path" "$target_path"
}

detect_available_platforms() {
  local found=()

  if [ -d "$HOME/.claude" ] || [ -d "$HOME/.claude/skills" ]; then
    found+=("claude")
  fi

  if [ -d "$HOME/.codex" ] || [ -d "$HOME/.codex/skills" ] || [ -d "$HOME/.Codex" ] || [ -d "$HOME/.Codex/skills" ]; then
    found+=("codex")
  fi

  if [ -d "$HOME/.openclaw" ] || [ -d "$HOME/.openclaw/skills" ]; then
    found+=("openclaw")
  fi

  printf '%s\n' "${found[@]}"
}

resolve_skill_root() {
  case "$1" in
    claude)
      printf '%s\n' "$HOME/.claude/skills"
      ;;
    codex)
      if [ -d "$HOME/.codex/skills" ] || [ ! -d "$HOME/.Codex/skills" ]; then
        printf '%s\n' "$HOME/.codex/skills"
      else
        printf '%s\n' "$HOME/.Codex/skills"
      fi
      ;;
    openclaw)
      printf '%s\n' "$HOME/.openclaw/skills"
      ;;
    *)
      err "不支持的平台：$1"
      exit 1
      ;;
  esac
}

install_dependency_skills() {
  local skill_root="$1"
  local dep dep_target dep_source

  for dep in "${DEP_SKILLS[@]}"; do
    dep_source="$SCRIPT_DIR/deps/$dep"
    dep_target="$skill_root/$dep"

    if [ ! -d "$dep_source" ]; then
      warn "$dep：deps/ 中未找到源文件，跳过"
      continue
    fi

    copy_item "$dep_source" "$dep_target"
    ok "$dep 已准备到 $dep_target"
  done
}

install_bundle() {
  local target_dir="$1"
  local item source_path target_path

  for item in "${MANAGED_ITEMS[@]}"; do
    source_path="$SCRIPT_DIR/$item"
    target_path="$target_dir/$item"

    if [ ! -e "$source_path" ]; then
      warn "$item：安装源文件缺失，跳过"
      continue
    fi

    if [ "$source_path" = "$target_path" ] && [ -e "$target_path" ]; then
      continue
    fi

    copy_item "$source_path" "$target_path"
  done
}

install_node_deps() {
  local skill_root="$1"
  local baoyu_dir="$skill_root/baoyu-url-to-markdown/scripts"

  if [ ! -d "$baoyu_dir" ] || [ ! -f "$baoyu_dir/package.json" ]; then
    return 0
  fi

  if [ -d "$baoyu_dir/node_modules" ]; then
    ok "baoyu-url-to-markdown 的 Node 依赖已存在"
    return 0
  fi

  info "安装 baoyu-url-to-markdown 的 Node 依赖..."

  if [ "$DRY_RUN" -eq 1 ]; then
    if command -v bun >/dev/null 2>&1; then
      printf '[dry-run] (cd %s && bun install)\n' "$baoyu_dir"
    elif command -v npm >/dev/null 2>&1; then
      printf '[dry-run] (cd %s && npm install)\n' "$baoyu_dir"
    else
      printf '[dry-run] 未找到 bun 或 npm，无法安装 Node 依赖\n'
    fi
    return 0
  fi

  if command -v bun >/dev/null 2>&1; then
    (cd "$baoyu_dir" && bun install) || warn "bun install 失败，跳过（可手动粘贴文本作为替代）"
  elif command -v npm >/dev/null 2>&1; then
    (cd "$baoyu_dir" && npm install) || warn "npm install 失败，跳过（可手动粘贴文本作为替代）"
  else
    warn "未找到 bun 或 npm，无法安装 Node 依赖"
    echo "  推荐安装 bun：curl -fsSL https://bun.sh/install | bash"
    return 0
  fi

  [ -d "$baoyu_dir/node_modules" ] && ok "baoyu-url-to-markdown 的 Node 依赖安装完成"
}

install_uv_tools() {
  if ! command -v uv >/dev/null 2>&1; then
    warn "未找到 uv，跳过 wechat-article-to-markdown 安装"
    echo "  安装 uv：curl -LsSf https://astral.sh/uv/install.sh | sh"
    return 0
  fi

  if command -v wechat-article-to-markdown >/dev/null 2>&1; then
    ok "wechat-article-to-markdown 已安装"
    return 0
  fi

  info "安装 wechat-article-to-markdown..."

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] uv tool install %s\n' "${WECHAT_TOOL_URL}"
    return 0
  fi

  uv tool install "${WECHAT_TOOL_URL}" \
    || warn "wechat-article-to-markdown 安装失败（可手动安装：uv tool install ${WECHAT_TOOL_URL}）"

  if command -v wechat-article-to-markdown >/dev/null 2>&1; then
    ok "wechat-article-to-markdown 安装完成"
  fi
}

check_environment() {
  echo ""
  echo "================================"
  echo "  环境检查"
  echo "================================"
  echo ""

  if command -v uv >/dev/null 2>&1; then
    ok "uv 已安装（可安装 wechat-article-to-markdown，并运行 youtube-transcript）"
  else
    warn "未找到 uv。wechat-article-to-markdown 和 youtube-transcript 需要 uv"
    echo "  可用 Homebrew 安装：brew install uv"
  fi

  if command -v wechat-article-to-markdown >/dev/null 2>&1; then
    ok "wechat-article-to-markdown 已可用"
  else
    warn "未找到 wechat-article-to-markdown。无法自动提取微信公众号"
    echo "  可手动安装：uv tool install ${WECHAT_TOOL_URL}"
  fi

  if command -v lsof >/dev/null 2>&1 && lsof -i :9222 -sTCP:LISTEN >/dev/null 2>&1; then
    ok "Chrome 调试端口 9222 已监听"
  else
    warn "Chrome 调试端口 9222 未监听。baoyu-url-to-markdown 需要 Chrome 以调试模式启动"
    echo "  请先执行：open -na \"Google Chrome\" --args --remote-debugging-port=9222"
  fi

  echo ""
  echo "提示：即使部分外挂不可用，PDF / 本地文件 / 纯文本仍可直接进入主线。"
}

print_source_boundary() {
  local core_sources optional_sources manual_sources

  core_sources="$(join_source_labels core_builtin)"
  optional_sources="$(join_source_labels optional_adapter)"
  manual_sources="$(join_source_labels manual_only)"

  echo ""
  echo "================================"
  echo "  来源边界"
  echo "================================"
  echo ""
  echo "核心主线：$core_sources"
  echo "可选外挂：$optional_sources"
  echo "手动入口：$manual_sources"
}

print_adapter_states() {
  local output

  echo ""
  echo "================================"
  echo "  外挂状态"
  echo "================================"
  echo ""

  output="$(
    bash "$ADAPTER_STATE_SCRIPT" --skill-root "$SKILL_ROOT" summary-human 2>&1
  )" || {
    warn "无法生成外挂状态摘要"
    printf '%s\n' "$output"
    return 0
  }

  printf '%s\n' "$output"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --platform)
      [ $# -ge 2 ] || { err "--platform 需要一个值"; usage; exit 1; }
      PLATFORM="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --target-dir)
      [ $# -ge 2 ] || { err "--target-dir 需要一个值"; usage; exit 1; }
      TARGET_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "未知参数：$1"
      usage
      exit 1
      ;;
  esac
done

if [ "$PLATFORM" = "auto" ]; then
  detected_platforms=()
  while IFS= read -r platform_name; do
    [ -n "$platform_name" ] && detected_platforms+=("$platform_name")
  done < <(detect_available_platforms)
  if [ "${#detected_platforms[@]}" -eq 1 ]; then
    PLATFORM="${detected_platforms[0]}"
  elif [ "${#detected_platforms[@]}" -eq 0 ]; then
    err "没有检测到受支持的平台目录。请显式传入 --platform claude|codex|openclaw"
    exit 1
  else
    err "检测到多个可用平台：${detected_platforms[*]}。请显式传入 --platform"
    exit 1
  fi
fi

SKILL_ROOT="$(resolve_skill_root "$PLATFORM")"
load_dependency_skills

if [ -n "$TARGET_DIR" ]; then
  TARGET_SKILL_DIR="$TARGET_DIR"
  SKILL_ROOT="$(dirname "$TARGET_SKILL_DIR")"
else
  TARGET_SKILL_DIR="$SKILL_ROOT/$SKILL_NAME"
fi

echo ""
echo "================================"
echo "  llm-wiki 安装"
echo "================================"
echo ""
echo "平台：$PLATFORM"
echo "技能根目录：$SKILL_ROOT"
echo "目标目录：$TARGET_SKILL_DIR"

run_cmd mkdir -p "$SKILL_ROOT"
run_cmd mkdir -p "$TARGET_SKILL_DIR"

install_bundle "$TARGET_SKILL_DIR"
install_dependency_skills "$SKILL_ROOT"
install_node_deps "$SKILL_ROOT"
install_uv_tools
print_source_boundary
check_environment
print_adapter_states

echo ""
ok "llm-wiki 已准备完成"
