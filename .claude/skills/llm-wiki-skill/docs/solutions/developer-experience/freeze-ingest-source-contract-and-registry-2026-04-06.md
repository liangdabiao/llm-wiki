---
title: Freeze ingest source contract and registry
date: 2026-04-06
last_updated: 2026-04-06
category: developer-experience
module: llm-wiki ingest sources
problem_type: developer_experience
component: development_workflow
symptoms:
  - Source rules were repeated across install, docs, status guidance, tests, and templates.
  - Bundled dependency skills and source-boundary labels could drift away from the shared registry.
  - Core path, optional adapter, and manual-only boundaries were frozen in data files but not enforced across every user-facing entry point.
  - Regression coverage did not prove that install output, README, schema guidance, and status guidance still matched the same source definition.
root_cause: missing_workflow_step
resolution_type: workflow_improvement
severity: medium
related_components:
  - documentation
  - tooling
  - testing_framework
tags: [ingest-sources, source-registry, source-contract, installer, regression]
---

# Freeze ingest source contract and registry

## Problem
Phase B needed one place to define what counts as a core ingest path, what counts as an optional adapter, and what stays manual-only. Freezing the source registry solved the data-model half of that problem, but the repo still needed a follow-through step: install output, status guidance, README, templates, and regression checks all had to actually read or mirror that same definition. Without that last-mile alignment, drift would have continued under a cleaner-looking shell.

## Symptoms
- Adding or reclassifying a source still risked touching multiple user-facing entry points that were not forced to stay on the same definition.
- The installer originally carried its own bundled dependency list instead of reading the same source definition used elsewhere.
- README, `SKILL.md`, and `templates/schema-template.md` could still describe source boundaries in slightly different words.
- Status guidance and fallback wording could drift away from the shared adapter-state model.
- There was no direct regression gate proving that install output, docs, templates, and tests still agreed on the same source labels.

## What Didn't Work
- Keeping the rules only in plan documents and todo notes did not protect the running repo from drift.
- Freezing the contract and registry files alone was not enough; the repo could still say “the registry is the source of truth” while README, templates, install output, and skill guidance each kept their own copy of the boundary.
- Updating a single file at a time did not solve the real problem, because the other entry points still preserved old source lists and old fallback wording.
- This was confirmed with a red-green check: new alignment assertions were added first, and they failed until the installer, README, `SKILL.md`, schema template, and regression coverage were all updated together.

## Solution
Freeze the source contract and source registry as two checked-in data files, add executable helpers that read and validate them, and then explicitly wire every consumer back to that shared definition.

The first file, [`scripts/source-record-contract.tsv`](../../scripts/source-record-contract.tsv), fixes the minimum shape every source record must satisfy before it enters the main wiki flow:

```text
source_id
source_label
source_category
input_mode
raw_dir
original_ref
ingest_text
adapter_name
fallback_hint
```

The second file, [`scripts/source-registry.tsv`](../../scripts/source-registry.tsv), freezes the boundary between the three source classes:

- `core_builtin`: `local_pdf`, `local_document`, `plain_text`
- `optional_adapter`: `web_article`, `x_twitter`, `wechat_article`, `youtube_video`, `zhihu_article`
- `manual_only`: `xiaohongshu_post`

It also records dependency and fallback data in the same place, including:

- bundled adapters: `baoyu-url-to-markdown`, `youtube-transcript`
- install-time adapter: `wechat-article-to-markdown`

[`scripts/source-registry.sh`](../../scripts/source-registry.sh) became the single executable entry point for this data:

```bash
bash scripts/source-registry.sh fields
bash scripts/source-registry.sh list
bash scripts/source-registry.sh get wechat_article
bash scripts/source-registry.sh list-by-category optional_adapter
bash scripts/source-registry.sh unique-dependencies bundled
bash scripts/source-registry.sh validate
```

The first win was making the installer read bundled dependency skills from that registry instead of keeping a separate hardcoded list:

```bash
while IFS= read -r dep; do
  [ -n "$dep" ] && DEP_SKILLS+=("$dep")
done < <(bash "$SOURCE_REGISTRY_SCRIPT" unique-dependencies bundled)
```

The follow-through step was to wire the human-facing boundary to the same model:

- [`install.sh`](../../install.sh) now prints the three source classes directly from the registry, then prints the shared adapter-state summary instead of inventing a second status list.
- [`README.md`](../../README.md) now points to `scripts/source-registry.tsv` as the authoritative source boundary and describes the same `核心主线 / 可选外挂 / 手动入口` split.
- [`SKILL.md`](../../SKILL.md) now tells ingest to read `source-registry.sh get <source_id>` and tells `status` to count sources by the registry’s `source_label` and `raw_dir`, while reusing `scripts/adapter-state.sh summary-human` instead of rewriting status text.
- [`templates/schema-template.md`](../../templates/schema-template.md) now mirrors the same three-way boundary and uses the same normalized labels such as `PDF / 本地 PDF` and `Markdown/文本/HTML`.

The install output now makes the boundary visible instead of implicit:

```bash
core_sources="$(join_source_labels core_builtin)"
optional_sources="$(join_source_labels optional_adapter)"
manual_sources="$(join_source_labels manual_only)"

echo "核心主线：$core_sources"
echo "可选外挂：$optional_sources"
echo "手动入口：$manual_sources"
```

[`tests/regression.sh`](../../tests/regression.sh) now locks the behavior by checking both the frozen data and the consumers that must stay aligned to it:

- the frozen contract fields
- source grouping into `core_builtin`, `optional_adapter`, and `manual_only`
- dependency grouping into bundled vs install-time
- registry validation success
- install bundle inclusion of `scripts/source-registry.sh`
- README, schema template, and install output all include the registry-backed source labels
- `SKILL.md` routes ingest and status through the shared registry and adapter-state helpers

The alignment assertions intentionally iterate over registry labels, so the checks fail when a user-facing entry point drifts off the source table:

```bash
assert_registry_labels_present_in_file "$REPO_ROOT/README.md" "core_builtin"
assert_registry_labels_present_in_file "$REPO_ROOT/templates/schema-template.md" "optional_adapter"
assert_registry_labels_present_in_text "$output" "manual_only"
```

The verification gate for this refreshed solution is now:

```bash
bash scripts/source-registry.sh validate
bash tests/adapter-state.sh
bash tests/regression.sh
bash install.sh --platform claude --dry-run
```

## Why This Works
The root cause was not a bad one-off decision. It was an unfinished workflow. Freezing the contract and registry created a shared truth, but the repo only stopped drifting once every important consumer was forced to read or mirror that truth and the regression suite checked the alignment directly.

That makes the Phase B boundary explicit:

- core paths stay available without adapters
- optional adapters are listed and grouped in one place
- manual-only sources stop pretending to be temporary automation failures
- install output, status output, README, and templates all describe that same boundary instead of approximating it

Changing a source now starts from the registry instead of from a hunt across unrelated files, and the test suite catches the places that forgot to follow along.

## Prevention
- When adding or changing a source, update [`scripts/source-record-contract.tsv`](../../scripts/source-record-contract.tsv) or [`scripts/source-registry.tsv`](../../scripts/source-registry.tsv) first, not a hand-maintained list in some consumer.
- Treat “freeze the registry” and “wire every consumer to it” as separate required steps. The work is not done when the table exists; it is done when install, docs, templates, and tests all follow it.
- Keep new consumers reading [`scripts/source-registry.sh`](../../scripts/source-registry.sh) and [`scripts/adapter-state.sh`](../../scripts/adapter-state.sh) instead of copying source rules or fallback wording into their own logic.
- Use a red-green check whenever you touch the boundary: add the alignment assertion first, watch it fail, then update the affected consumer.
- Treat these checks as the minimum completion gate for source-boundary work:

```bash
bash scripts/source-registry.sh validate
bash tests/adapter-state.sh
bash tests/regression.sh
bash install.sh --platform claude --dry-run
```

- If a follow-on task starts depending on the registry, link back to this document instead of re-explaining the contract from scratch.
- If a source change touches install or status output, verify that the printed labels still match the registry-backed Chinese names the user actually sees.

## Related Issues
- Upstream plan: [2026-04-06-002-phase-b-core-and-adapter-separation-plan.md](../../plans/2026-04-06-002-phase-b-core-and-adapter-separation-plan.md)
- Upstream requirements: [2026-04-06-project-cleanup-and-restructuring-requirements.md](../../brainstorms/2026-04-06-project-cleanup-and-restructuring-requirements.md)
- Task 004 follow-through: [.context/compound-engineering/todos/004-ready-p2-align-install-status-docs-and-regression.md](../../../../.context/compound-engineering/todos/004-ready-p2-align-install-status-docs-and-regression.md)
- Follow-on adapter state work: [unify-optional-adapter-states-and-fallback-paths-2026-04-06.md](../integration-issues/unify-optional-adapter-states-and-fallback-paths-2026-04-06.md)
- Related but distinct compatibility work: [legacy-wiki-lazy-compatibility-2026-04-06.md](../workflow-issues/legacy-wiki-lazy-compatibility-2026-04-06.md)
- GitHub issues: none found with `gh issue list --search "source registry adapter contract" --state all --limit 5`
