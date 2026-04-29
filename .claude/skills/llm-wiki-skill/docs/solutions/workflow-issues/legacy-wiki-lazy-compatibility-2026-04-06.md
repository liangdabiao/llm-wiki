---
title: Protect legacy wikis with lazy compatibility defaults
date: 2026-04-06
category: workflow-issues
module: llm-wiki legacy compatibility
problem_type: workflow_issue
component: tooling
symptoms:
  - Legacy wikis had no executable rule for missing schema fields such as language or version
  - Newly introduced raw source directories could have turned old layouts into mandatory migrations
  - There was no regression coverage proving old materials stayed usable without relocation
root_cause: missing_tooling
resolution_type: tooling_addition
severity: medium
related_components:
  - documentation
  - development_workflow
tags: [legacy-wiki, compatibility, lazy-migration, regression-coverage, wiki-schema]
---

# Protect legacy wikis with lazy compatibility defaults

## Problem
Phase B froze a new source registry and future-facing structure, but the repo still lacked an executable rule for how pre-existing wikis should keep working. Without that guard, old knowledge bases were one refactor away from an accidental forced migration, even though the plan explicitly said compatibility had to come first.

## Symptoms
- Old knowledge bases with no explicit `语言` or `版本` field had no verified default behavior.
- Legacy layouts missing newer raw directories like `raw/xiaohongshu` and `raw/zhihu` had no approved non-breaking path.
- There was no regression test proving old materials could stay in place while new directories were added later.

## What Didn't Work
- Relying on the plan and todo text alone was not enough; nothing in the repo could actually inspect or validate a legacy wiki.
- Treating every current raw directory as mandatory would have broken older wiki layouts immediately.
- Solving the problem with a migration step would have made the structure cleaner, but it directly violated the Phase B goal of “compatibility first, migration later.”

## Solution
We added a dedicated compatibility helper, `scripts/wiki-compat.sh`, and taught it three behaviors:
1. Inspect or validate a wiki against the legacy minimum layout instead of the newest full layout.
2. Default missing schema metadata to the old-safe values (`version=1.0`, `language=zh`).
3. Create newly introduced raw directories only when they are actually needed.

```bash
bash scripts/wiki-compat.sh inspect <wiki_root>
bash scripts/wiki-compat.sh validate <wiki_root>
bash scripts/wiki-compat.sh ensure-source-dir <wiki_root> <source_id>
```

The core defaulting logic is intentionally small and explicit:

```bash
resolved_schema_version() {
  schema_field_value "$wiki_root" "版本" "1.0"
}

resolved_language() {
  raw_value="$(schema_field_value "$wiki_root" "语言" "")"
  case "$raw_value" in
    English|english|EN|en) printf 'en\n' ;;
    *) printf 'zh\n' ;;
  esac
}
```

Optional directories are detected from the source registry, but only the legacy floor is required:

```bash
if is_legacy_required_raw_dir "$raw_dir"; then
  continue
fi

if [ ! -d "$wiki_root/$raw_dir" ]; then
  missing+=("$raw_dir")
fi
```

The verified legacy inspect output now makes the compatibility decision explicit:

```text
schema_version=1.0
language=zh
legacy_mode=yes
migration_required=no
missing_optional_raw_dirs=raw/xiaohongshu,raw/zhihu
```

We also added regression coverage that builds a legacy wiki fixture, verifies the defaulted inspect output, and proves that `ensure-source-dir` can add a new directory without moving an old source file.

## Why This Works
The fix moves compatibility rules out of planning text and into code that can be run and tested. Old wikis are validated against the directories and files they were originally promised, while newer source directories stay optional until first use. That keeps the source registry as the future source of truth without letting it retroactively invalidate existing knowledge bases.

The result is a clear contract:
- old schemas can omit newer fields and still load with stable defaults
- old materials stay where they already are
- new directories appear lazily when a new source type needs them
- migration remains unnecessary unless a future structure becomes truly impossible to represent through defaults

## Prevention
- Keep the legacy minimum layout explicit in one executable helper instead of scattering it across plan text and assumptions.
- Add a regression whenever a new schema field or raw directory is introduced:
  - one check for missing-field defaults
  - one check for lazy directory creation
  - one check that existing materials remain untouched
- Treat `migration_required=no` as the default until a concrete incompatibility is proven.
- Before adding any new source type, decide whether it is:
  - required for all old wikis
  - optional and lazily creatable
  - incompatible enough to justify a real migration command
- Re-run the full regression suite after compatibility changes:

```bash
bash tests/regression.sh
```

## Related Issues
- No existing `docs/solutions/` entry covered this problem.
- Related planning/context docs:
  - `docs/plans/2026-04-06-002-phase-b-core-and-adapter-separation-plan.md`
  - `.context/compound-engineering/todos/003-ready-p1-protect-legacy-wikis-and-migration-rules.md`
  - `docs/brainstorms/2026-04-06-project-cleanup-and-restructuring-requirements.md`
- GitHub issue search via `gh issue list --search "legacy wiki compatibility migration" --state all --limit 5` returned no matching issues.
