#!/bin/bash

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

assert_file_not_contains() {
    local file="$1"
    local text="$2"

    if grep -F -- "$text" "$file" > /dev/null; then
        fail "Expected $file to not contain: $text"
    fi
}

assert_text_contains() {
    local text="$1"
    local expected="$2"

    if ! printf '%s' "$text" | grep -F -- "$expected" > /dev/null; then
        fail "Expected output to contain: $expected"
    fi
}

assert_path_exists() {
    local path="$1"

    [ -e "$path" ] || fail "Expected path to exist: $path"
}

each_registry_label() {
    local category="$1"

    bash "$REPO_ROOT/scripts/source-registry.sh" list-by-category "$category" \
        | awk -F '\t' 'NF { print $2 }'
}

assert_registry_labels_present_in_text() {
    local text="$1"
    local category="$2"
    local label

    while IFS= read -r label; do
        [ -n "$label" ] || continue
        assert_text_contains "$text" "$label"
    done <<EOF
$(each_registry_label "$category")
EOF
}

assert_registry_labels_present_in_file() {
    local file="$1"
    local category="$2"
    local label

    while IFS= read -r label; do
        [ -n "$label" ] || continue
        assert_file_contains "$file" "$label"
    done <<EOF
$(each_registry_label "$category")
EOF
}

make_stub() {
    local path="$1"
    local body="$2"

    printf '%s\n' "$body" > "$path"
    chmod +x "$path"
}

make_legacy_wiki() {
    local wiki_root="$1"

    mkdir -p "$wiki_root"/raw/{articles,tweets,wechat,pdfs,notes,assets}
    mkdir -p "$wiki_root"/wiki/{entities,topics,sources,comparisons,synthesis}

    cat > "$wiki_root/.wiki-schema.md" <<'EOF'
# Wiki Schema（知识库配置规范）

- 主题：旧知识库
- 创建日期：2026-04-01
EOF

    printf '# 索引\n' > "$wiki_root/index.md"
    printf '# 日志\n' > "$wiki_root/log.md"
    printf '# 总览\n' > "$wiki_root/wiki/overview.md"
}

test_setup_runs_on_bash_3_2() {
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
printf '%s\n' \"\$*\" >> \"$tmp_dir/uv.log\"
printf '%s\n' '#!/bin/sh' 'exit 0' > \"$tmp_dir/bin/wechat-article-to-markdown\"
chmod +x \"$tmp_dir/bin/wechat-article-to-markdown\"
exit 0"

    output="$(
        HOME="$tmp_dir/home" \
        PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$REPO_ROOT/setup.sh" 2>&1
    )" || fail "setup.sh should run successfully under bash 3.2"

    [ -d "$tmp_dir/home/.claude/skills/baoyu-url-to-markdown" ] || fail "Expected baoyu-url-to-markdown to be installed"
    [ -d "$tmp_dir/home/.claude/skills/youtube-transcript" ] || fail "Expected youtube-transcript to be installed"
    [ ! -d "$tmp_dir/home/.claude/skills/x-article-extractor" ] || fail "Did not expect x-article-extractor to be installed"
    assert_path_exists "$tmp_dir/bin/wechat-article-to-markdown"
    assert_file_contains "$tmp_dir/uv.log" "tool install git+https://github.com/jackwener/wechat-article-to-markdown.git"

    assert_text_contains "$output" "Chrome 调试端口 9222 未监听"
    assert_text_contains "$output" "open -na \"Google Chrome\" --args --remote-debugging-port=9222"
    assert_text_contains "$output" "wechat-article-to-markdown 安装完成"
}

test_install_dry_run_for_claude() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.claude/skills"

    output="$(
        HOME="$tmp_dir/home" \
        bash "$REPO_ROOT/install.sh" --platform claude --dry-run 2>&1
    )" || fail "install.sh dry-run for Claude should succeed"

    assert_text_contains "$output" "平台：claude"
    assert_text_contains "$output" "$tmp_dir/home/.claude/skills/llm-wiki"
}

test_install_auto_refuses_ambiguous_platforms() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.claude/skills" "$tmp_dir/home/.codex/skills"

    if output="$(
        HOME="$tmp_dir/home" \
        bash "$REPO_ROOT/install.sh" --platform auto 2>&1
    )"; then
        fail "install.sh auto should fail when multiple platform homes are present"
    fi

    assert_text_contains "$output" "检测到多个可用平台"
    assert_text_contains "$output" "--platform"
}

test_install_openclaw_copies_bundle() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.openclaw/skills" "$tmp_dir/bin"

    make_stub "$tmp_dir/bin/bun" '#!/bin/sh
mkdir -p node_modules
exit 0'

    make_stub "$tmp_dir/bin/lsof" '#!/bin/sh
exit 1'

    HOME="$tmp_dir/home" \
    PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    bash "$REPO_ROOT/install.sh" --platform openclaw > /dev/null 2>&1 || fail "install.sh should install for OpenClaw"

    assert_path_exists "$tmp_dir/home/.openclaw/skills/llm-wiki/SKILL.md"
    assert_path_exists "$tmp_dir/home/.openclaw/skills/llm-wiki/install.sh"
    assert_path_exists "$tmp_dir/home/.openclaw/skills/llm-wiki/scripts/source-registry.sh"
    assert_path_exists "$tmp_dir/home/.openclaw/skills/baoyu-url-to-markdown"
}

test_init_fills_language_placeholder() {
    local tmp_dir wiki_root
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wiki_root="$tmp_dir/Test Wiki"
    bash "$REPO_ROOT/scripts/init-wiki.sh" "$wiki_root" "测试主题" "English" > /dev/null

    assert_file_contains "$wiki_root/.wiki-schema.md" "- 语言：English"
    assert_file_not_contains "$wiki_root/.wiki-schema.md" "{{LANGUAGE}}"
}

test_readme_sections() {
    assert_file_contains "$REPO_ROOT/README.md" "## 前置条件"
    assert_file_contains "$REPO_ROOT/README.md" "## 常见问题"
    assert_file_contains "$REPO_ROOT/README.md" "bash install.sh --platform claude"
    assert_file_contains "$REPO_ROOT/README.md" "bash install.sh --platform codex"
    assert_file_contains "$REPO_ROOT/README.md" "bash install.sh --platform openclaw"
    assert_file_contains "$REPO_ROOT/README.md" "wechat-article-to-markdown"
    assert_file_not_contains "$REPO_ROOT/README.md" "x-article-extractor"
    assert_file_not_contains "$REPO_ROOT/README.md" "baoyu-danger-x-to-markdown"
}

test_uv_tool_install_failure_is_graceful() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.claude/skills" "$tmp_dir/bin"

    make_stub "$tmp_dir/bin/bun" '#!/bin/sh
mkdir -p node_modules
exit 0'

    make_stub "$tmp_dir/bin/lsof" '#!/bin/sh
exit 1'

    make_stub "$tmp_dir/bin/uv" '#!/bin/sh
exit 1'

    output="$(
        HOME="$tmp_dir/home" \
        PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$REPO_ROOT/install.sh" --platform claude 2>&1
    )" || fail "install.sh should keep going when uv tool install fails"

    assert_text_contains "$output" "wechat-article-to-markdown 安装失败"
    assert_text_contains "$output" "llm-wiki 已准备完成"
    assert_path_exists "$tmp_dir/home/.claude/skills/llm-wiki/SKILL.md"
}

test_skill_md_routes_wechat_to_new_tool() {
    assert_file_contains "$REPO_ROOT/SKILL.md" "scripts/source-registry.sh match-url"
    assert_file_contains "$REPO_ROOT/SKILL.md" "scripts/source-registry.sh match-file"
    assert_file_contains "$REPO_ROOT/SKILL.md" '`adapter_name`'
    assert_file_not_contains "$REPO_ROOT/SKILL.md" "x-article-extractor"
}

test_templates_have_no_empty_links() {
    assert_file_not_contains "$REPO_ROOT/templates/entity-template.md" "- [[]]"
    assert_file_not_contains "$REPO_ROOT/templates/source-template.md" "- [[]]"
    assert_file_not_contains "$REPO_ROOT/templates/topic-template.md" "- [[]]"
}

test_batch_ingest_has_step_two() {
    local section
    section="$(sed -n '/## 工作流 3：batch-ingest/,/## 工作流 4：query/p' "$REPO_ROOT/SKILL.md")"

    assert_text_contains "$section" "1. **确认知识库路径**"
    assert_text_contains "$section" "2. **列出所有可处理文件**"
    assert_text_contains "$section" "3. **展示文件列表**"
}

test_english_templates_exist_and_have_placeholders() {
    assert_path_exists "$REPO_ROOT/templates/index-en-template.md"
    assert_path_exists "$REPO_ROOT/templates/overview-en-template.md"
    assert_path_exists "$REPO_ROOT/templates/log-en-template.md"

    assert_file_contains "$REPO_ROOT/templates/index-en-template.md" "{{DATE}}"
    assert_file_contains "$REPO_ROOT/templates/index-en-template.md" "{{TOPIC}}"
    assert_file_contains "$REPO_ROOT/templates/overview-en-template.md" "{{DATE}}"
    assert_file_contains "$REPO_ROOT/templates/overview-en-template.md" "{{TOPIC}}"
    assert_file_contains "$REPO_ROOT/templates/log-en-template.md" "{{DATE}}"
    assert_file_contains "$REPO_ROOT/templates/log-en-template.md" "{{TOPIC}}"
}

test_english_templates_have_no_empty_links() {
    assert_file_not_contains "$REPO_ROOT/templates/index-en-template.md" "[[]]"
    assert_file_not_contains "$REPO_ROOT/templates/overview-en-template.md" "[[]]"
    assert_file_not_contains "$REPO_ROOT/templates/log-en-template.md" "[[]]"
}

test_skill_md_has_shared_preflight_and_language_rules() {
    assert_file_contains "$REPO_ROOT/SKILL.md" "## 通用前置检查"
    assert_file_contains "$REPO_ROOT/SKILL.md" "## 输出语言规则"
    assert_file_contains "$REPO_ROOT/SKILL.md" "素材 → Source"
    assert_file_contains "$REPO_ROOT/SKILL.md" "知识图谱 → Knowledge Graph"
}

test_skill_md_uses_external_english_templates_and_no_english_output_blocks() {
    assert_file_contains "$REPO_ROOT/SKILL.md" "templates/index-en-template.md"
    assert_file_contains "$REPO_ROOT/SKILL.md" "templates/overview-en-template.md"
    assert_file_contains "$REPO_ROOT/SKILL.md" "templates/log-en-template.md"
    assert_file_not_contains "$REPO_ROOT/SKILL.md" "**English（en）**："
}

test_setup_wrapper_is_marked_deprecated() {
    assert_file_contains "$REPO_ROOT/setup.sh" "已废弃：请使用 bash install.sh --platform claude"
}

test_source_registry_contract_is_frozen() {
    local output

    output="$(
        bash "$REPO_ROOT/scripts/source-registry.sh" fields 2>&1
    )" || fail "source-registry fields should be readable"

    assert_text_contains "$output" "source_id"
    assert_text_contains "$output" "source_label"
    assert_text_contains "$output" "source_category"
    assert_text_contains "$output" "input_mode"
    assert_text_contains "$output" "raw_dir"
    assert_text_contains "$output" "original_ref"
    assert_text_contains "$output" "ingest_text"
    assert_text_contains "$output" "adapter_name"
    assert_text_contains "$output" "fallback_hint"
}

test_source_registry_groups_core_optional_and_manual_sources() {
    local output

    output="$(
        bash "$REPO_ROOT/scripts/source-registry.sh" list 2>&1
    )" || fail "source-registry list should be readable"

    assert_text_contains "$output" "core_builtin"
    assert_text_contains "$output" "optional_adapter"
    assert_text_contains "$output" "manual_only"
    assert_text_contains "$output" "local_pdf"
    assert_text_contains "$output" "plain_text"
    assert_text_contains "$output" "web_article"
    assert_text_contains "$output" "wechat_article"
    assert_text_contains "$output" "xiaohongshu_post"
}

test_source_registry_exposes_install_dependency_groups() {
    local bundled_output install_time_output

    bundled_output="$(
        bash "$REPO_ROOT/scripts/source-registry.sh" unique-dependencies bundled 2>&1
    )" || fail "source-registry should list bundled dependencies"

    install_time_output="$(
        bash "$REPO_ROOT/scripts/source-registry.sh" unique-dependencies install_time 2>&1
    )" || fail "source-registry should list install-time dependencies"

    assert_text_contains "$bundled_output" "baoyu-url-to-markdown"
    assert_text_contains "$bundled_output" "youtube-transcript"
    assert_text_contains "$install_time_output" "wechat-article-to-markdown"
}

test_source_registry_validation_passes() {
    bash "$REPO_ROOT/scripts/source-registry.sh" validate > /dev/null 2>&1 \
        || fail "source-registry validate should succeed"
}

test_source_registry_matches_urls_and_files_from_shared_table() {
    local output

    output="$(
        bash "$REPO_ROOT/scripts/source-registry.sh" match-url "https://x.com/openai/status/1" 2>&1
    )" || fail "source-registry should match X/Twitter URLs"
    assert_text_contains "$output" "x_twitter"

    output="$(
        bash "$REPO_ROOT/scripts/source-registry.sh" match-url "https://mp.weixin.qq.com/s/example" 2>&1
    )" || fail "source-registry should match WeChat URLs"
    assert_text_contains "$output" "wechat_article"

    output="$(
        bash "$REPO_ROOT/scripts/source-registry.sh" match-url "https://example.com/post" 2>&1
    )" || fail "source-registry should match generic web URLs"
    assert_text_contains "$output" "web_article"

    output="$(
        bash "$REPO_ROOT/scripts/source-registry.sh" match-file "/tmp/example.md" 2>&1
    )" || fail "source-registry should match local document files"
    assert_text_contains "$output" "local_document"

    output="$(
        bash "$REPO_ROOT/scripts/source-registry.sh" match-file "/tmp/paper.pdf" 2>&1
    )" || fail "source-registry should match PDF files"
    assert_text_contains "$output" "local_pdf"
}

test_legacy_wiki_defaults_missing_fields_without_forcing_migration() {
    local tmp_dir wiki_root output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wiki_root="$tmp_dir/legacy-wiki"
    make_legacy_wiki "$wiki_root"

    output="$(
        bash "$REPO_ROOT/scripts/wiki-compat.sh" inspect "$wiki_root" 2>&1
    )" || fail "legacy wiki inspect should succeed without migration"

    assert_text_contains "$output" "schema_version=1.0"
    assert_text_contains "$output" "language=zh"
    assert_text_contains "$output" "migration_required=no"
    assert_text_contains "$output" "missing_optional_raw_dirs=raw/xiaohongshu,raw/zhihu"

    bash "$REPO_ROOT/scripts/wiki-compat.sh" validate "$wiki_root" > /dev/null 2>&1 \
        || fail "legacy wiki validate should accept the old layout"
}

test_legacy_wiki_lazily_creates_new_source_dirs_without_moving_old_materials() {
    local tmp_dir wiki_root output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wiki_root="$tmp_dir/legacy-wiki"
    make_legacy_wiki "$wiki_root"
    printf '旧素材\n' > "$wiki_root/raw/articles/2026-04-01-old-source.md"

    bash "$REPO_ROOT/scripts/wiki-compat.sh" ensure-source-dir "$wiki_root" xiaohongshu_post > /dev/null 2>&1 \
        || fail "legacy wiki should lazily create missing source directories"

    assert_path_exists "$wiki_root/raw/xiaohongshu"
    assert_path_exists "$wiki_root/raw/articles/2026-04-01-old-source.md"

    output="$(
        bash "$REPO_ROOT/scripts/wiki-compat.sh" inspect "$wiki_root" 2>&1
    )" || fail "inspect should still succeed after lazily creating a source directory"

    assert_text_contains "$output" "missing_optional_raw_dirs=raw/zhihu"
}

test_readme_aligns_source_boundary_to_registry() {
    assert_file_contains "$REPO_ROOT/README.md" "scripts/source-registry.tsv"
    assert_file_contains "$REPO_ROOT/README.md" "核心主线"
    assert_file_contains "$REPO_ROOT/README.md" "可选外挂"
    assert_file_contains "$REPO_ROOT/README.md" "手动入口"
    assert_registry_labels_present_in_file "$REPO_ROOT/README.md" "core_builtin"
    assert_registry_labels_present_in_file "$REPO_ROOT/README.md" "optional_adapter"
    assert_registry_labels_present_in_file "$REPO_ROOT/README.md" "manual_only"
}

test_skill_status_and_ingest_align_to_registry() {
    assert_file_contains "$REPO_ROOT/SKILL.md" "scripts/source-registry.sh list"
    assert_file_contains "$REPO_ROOT/SKILL.md" "scripts/source-registry.sh get"
    assert_file_contains "$REPO_ROOT/SKILL.md" "source_id"
    assert_file_contains "$REPO_ROOT/SKILL.md" "recovery_action"
    assert_file_contains "$REPO_ROOT/SKILL.md" "install_hint"
    assert_file_contains "$REPO_ROOT/SKILL.md" '按来源总表中的 `source_label` 和 `raw_dir`'
    assert_file_contains "$REPO_ROOT/SKILL.md" "外挂状态直接使用"
}

test_schema_template_aligns_source_boundary_to_registry() {
    assert_file_contains "$REPO_ROOT/templates/schema-template.md" "核心主线"
    assert_file_contains "$REPO_ROOT/templates/schema-template.md" "可选外挂"
    assert_file_contains "$REPO_ROOT/templates/schema-template.md" "手动入口"
    assert_registry_labels_present_in_file "$REPO_ROOT/templates/schema-template.md" "core_builtin"
    assert_registry_labels_present_in_file "$REPO_ROOT/templates/schema-template.md" "optional_adapter"
    assert_registry_labels_present_in_file "$REPO_ROOT/templates/schema-template.md" "manual_only"
}

test_install_prints_source_boundary_from_registry() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.claude/skills"

    output="$(
        HOME="$tmp_dir/home" \
        bash "$REPO_ROOT/install.sh" --platform claude --dry-run 2>&1
    )" || fail "install.sh dry-run should print shared source boundary"

    assert_text_contains "$output" "来源边界"
    assert_text_contains "$output" "核心主线"
    assert_text_contains "$output" "可选外挂"
    assert_text_contains "$output" "手动入口"
    assert_registry_labels_present_in_text "$output" "core_builtin"
    assert_registry_labels_present_in_text "$output" "optional_adapter"
    assert_registry_labels_present_in_text "$output" "manual_only"
}

test_install_warns_when_managed_source_is_missing() {
    assert_file_contains "$REPO_ROOT/install.sh" "安装源文件缺失，跳过"
}

test_setup_runs_on_bash_3_2
test_install_dry_run_for_claude
test_install_auto_refuses_ambiguous_platforms
test_install_openclaw_copies_bundle
test_init_fills_language_placeholder
test_readme_sections
test_uv_tool_install_failure_is_graceful
test_skill_md_routes_wechat_to_new_tool
test_templates_have_no_empty_links
test_batch_ingest_has_step_two
test_english_templates_exist_and_have_placeholders
test_english_templates_have_no_empty_links
test_skill_md_has_shared_preflight_and_language_rules
test_skill_md_uses_external_english_templates_and_no_english_output_blocks
test_setup_wrapper_is_marked_deprecated
test_source_registry_contract_is_frozen
test_source_registry_groups_core_optional_and_manual_sources
test_source_registry_exposes_install_dependency_groups
test_source_registry_validation_passes
test_source_registry_matches_urls_and_files_from_shared_table
test_legacy_wiki_defaults_missing_fields_without_forcing_migration
test_legacy_wiki_lazily_creates_new_source_dirs_without_moving_old_materials
test_readme_aligns_source_boundary_to_registry
test_skill_status_and_ingest_align_to_registry
test_schema_template_aligns_source_boundary_to_registry
test_install_prints_source_boundary_from_registry
test_install_warns_when_managed_source_is_missing

bash "$REPO_ROOT/tests/adapter-state.sh" || fail "adapter-state.sh 测试失败"

echo "All regression checks passed."
