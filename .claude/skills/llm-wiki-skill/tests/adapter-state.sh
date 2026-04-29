#!/bin/bash
# 外挂状态检测的回归测试
# 覆盖：not_installed / env_unavailable / runtime_failed / empty_result / unsupported

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

assert_file_contains() {
    local file="$1"
    local text="$2"

    if ! grep -F -- "$text" "$file" > /dev/null; then
        fail "Expected $file to contain: $text"
    fi
}

assert_text_contains() {
    local text="$1"
    local expected="$2"

    if ! printf '%s' "$text" | grep -F -- "$expected" > /dev/null; then
        fail "Expected output to contain: $expected"
    fi
}

make_stub() {
    local path="$1"
    local body="$2"

    printf '%s\n' "$body" > "$path"
    chmod +x "$path"
}

prepare_skill_root() {
    local skill_root="$1"

    mkdir -p "$skill_root/baoyu-url-to-markdown"
    mkdir -p "$skill_root/youtube-transcript"
}

test_bundled_adapters_are_not_treated_as_installed_from_repo_checkout() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/bin" "$tmp_dir/skills"

    make_stub "$tmp_dir/bin/lsof" '#!/bin/sh
exit 1'

    output="$(
        PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$REPO_ROOT/scripts/adapter-state.sh" --skill-root "$tmp_dir/skills" check web_article 2>&1
    )" || fail "adapter-state should check the target skill root, not the repo checkout"

    assert_text_contains "$output" "not_installed"
    assert_text_contains "$output" "baoyu-url-to-markdown"
}

test_adapter_state_distinguishes_not_installed_and_unsupported() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/bin" "$tmp_dir/skills"
    make_stub "$tmp_dir/bin/uv" '#!/bin/sh
exit 0'

    output="$(
        PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$REPO_ROOT/scripts/adapter-state.sh" --skill-root "$tmp_dir/skills" check wechat_article 2>&1
    )" || fail "adapter-state should classify not_installed"

    assert_text_contains "$output" "not_installed"
    assert_text_contains "$output" "wechat-article-to-markdown"
    assert_text_contains "$output" "手动入口"

    output="$(
        PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$REPO_ROOT/scripts/adapter-state.sh" --skill-root "$tmp_dir/skills" check xiaohongshu_post 2>&1
    )" || fail "adapter-state should classify unsupported"

    assert_text_contains "$output" "unsupported"
    assert_text_contains "$output" "请先从 App 或网页复制内容"
}

test_adapter_state_distinguishes_env_unavailable() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/bin" "$tmp_dir/skills"
    prepare_skill_root "$tmp_dir/skills"

    make_stub "$tmp_dir/bin/lsof" '#!/bin/sh
exit 1'

    output="$(
        PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$REPO_ROOT/scripts/adapter-state.sh" --skill-root "$tmp_dir/skills" check web_article 2>&1
    )" || fail "adapter-state should classify env_unavailable for Chrome-backed sources"

    assert_text_contains "$output" "env_unavailable"
    assert_text_contains "$output" "Chrome"

    output="$(
        PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$REPO_ROOT/scripts/adapter-state.sh" --skill-root "$tmp_dir/skills" check youtube_video 2>&1
    )" || fail "adapter-state should classify env_unavailable for uv-backed sources"

    assert_text_contains "$output" "env_unavailable"
    assert_text_contains "$output" "uv"
}

test_adapter_state_distinguishes_runtime_failed_and_empty_result() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/bin" "$tmp_dir/skills"
    prepare_skill_root "$tmp_dir/skills"

    make_stub "$tmp_dir/bin/lsof" '#!/bin/sh
exit 0'
    make_stub "$tmp_dir/bin/uv" '#!/bin/sh
exit 0'

    : > "$tmp_dir/empty.txt"
    printf 'body\n' > "$tmp_dir/full.txt"

    output="$(
        PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$REPO_ROOT/scripts/adapter-state.sh" --skill-root "$tmp_dir/skills" classify-run web_article 1 "$tmp_dir/full.txt" 2>&1
    )" || fail "adapter-state should classify runtime_failed"

    assert_text_contains "$output" "runtime_failed"
    assert_text_contains "$output" "重试"

    output="$(
        PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$REPO_ROOT/scripts/adapter-state.sh" --skill-root "$tmp_dir/skills" classify-run web_article 0 "$tmp_dir/empty.txt" 2>&1
    )" || fail "adapter-state should classify empty_result"

    assert_text_contains "$output" "empty_result"
    assert_text_contains "$output" "手动补全文本"

    output="$(
        PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$REPO_ROOT/scripts/adapter-state.sh" --skill-root "$tmp_dir/skills" classify-run web_article 0 "$tmp_dir/full.txt" 2>&1
    )" || fail "adapter-state should keep available runs green"

    assert_text_contains "$output" "available"
}

test_install_reports_adapter_states_from_shared_model() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.claude/skills" "$tmp_dir/bin"

    make_stub "$tmp_dir/bin/bun" '#!/bin/sh
mkdir -p node_modules
exit 0'

    make_stub "$tmp_dir/bin/lsof" '#!/bin/sh
exit 1'

    make_stub "$tmp_dir/bin/uv" "#!/bin/sh
printf '%s\n' '#!/bin/sh' 'exit 0' > \"$tmp_dir/bin/wechat-article-to-markdown\"
chmod +x \"$tmp_dir/bin/wechat-article-to-markdown\"
exit 0"

    output="$(
        HOME="$tmp_dir/home" \
        PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$REPO_ROOT/install.sh" --platform claude 2>&1
    )" || fail "install.sh should surface adapter states"

    assert_text_contains "$output" "外挂状态"
    assert_text_contains "$output" "网页文章"
    assert_text_contains "$output" "环境不满足"
    assert_text_contains "$output" "微信公众号"
    assert_text_contains "$output" "可用"
}

test_skill_routes_ingest_and_status_through_adapter_state_model() {
    assert_file_contains "$REPO_ROOT/SKILL.md" "scripts/adapter-state.sh"
    assert_file_contains "$REPO_ROOT/SKILL.md" "not_installed / env_unavailable / runtime_failed / unsupported / empty_result"
    assert_file_contains "$REPO_ROOT/SKILL.md" "外挂状态"
}

test_adapter_state_distinguishes_not_installed_and_unsupported
test_bundled_adapters_are_not_treated_as_installed_from_repo_checkout
test_adapter_state_distinguishes_env_unavailable
test_adapter_state_distinguishes_runtime_failed_and_empty_result
test_install_reports_adapter_states_from_shared_model
test_skill_routes_ingest_and_status_through_adapter_state_model

echo "Adapter state checks passed."
