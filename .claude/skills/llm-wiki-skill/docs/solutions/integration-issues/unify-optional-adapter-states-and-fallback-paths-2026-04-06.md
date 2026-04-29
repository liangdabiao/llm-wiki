---
title: Unify optional adapter states and fallback paths
date: 2026-04-06
category: integration-issues
module: llm-wiki adapter routing
problem_type: integration_issue
component: tooling
symptoms:
  - Optional adapter failures could collapse into a vague extraction failure instead of telling users whether they needed to install something, fix the environment, retry, or switch to manual input.
  - Install output, ingest guidance, and status guidance had no executable shared state model, so the same adapter problem could be described differently in different entry points.
  - Phase B required the core wiki path to stay usable even when adapters failed, but there was no single helper enforcing that separation.
root_cause: missing_tooling
resolution_type: tooling_addition
severity: medium
related_components:
  - documentation
  - development_workflow
tags: [adapter-state, fallback-paths, optional-adapters, source-registry, install-status]
---

# Unify optional adapter states and fallback paths

## Problem
Phase B needed a hard rule that optional adapters could fail without confusing the user or disrupting the core wiki path. Before this fix, the repo had source metadata and fallback hints, but no shared executable layer turning those rules into consistent install, ingest, and status behavior.

## Symptoms
- Users could hit the same adapter problem and get different guidance depending on whether they were installing the skill, ingesting a URL, or checking status.
- Manual-only sources such as Xiaohongshu were easy to blur together with temporary runtime failures, even though the right next step was completely different.
- The core path for PDF, local files, and pasted text was supposed to stay stable, but adapter-specific failures still had no explicit boundary separating “optional adapter issue” from “core wiki issue.”

## What Didn't Work
- Keeping fallback guidance only in `scripts/source-registry.tsv` was not enough. The hints existed, but install and status flows had no shared helper using them.
- Treating every adapter problem as “automatic extraction failed” hid the difference between `not_installed`, `env_unavailable`, `runtime_failed`, `unsupported`, and `empty_result`.
- Letting each entry point grow its own checks would have duplicated dependency and environment logic, making drift more likely as Phase B kept evolving.

## Solution
Add a single adapter-state helper, wire install and skill guidance through it, and lock the behavior with focused tests.

The new helper lives in `scripts/adapter-state.sh` and exposes four small entry points:

```bash
bash scripts/adapter-state.sh check <source_id>
bash scripts/adapter-state.sh summary
bash scripts/adapter-state.sh summary-human
bash scripts/adapter-state.sh classify-run <source_id> <exit_code> <output_path>
```

It reads `scripts/source-registry.tsv`, then turns optional sources into a shared state model:

- `not_installed`: the adapter is missing
- `env_unavailable`: the adapter exists, but a prerequisite like `uv` or Chrome debugging is unavailable
- `runtime_failed`: the extraction command ran and failed
- `unsupported`: the source is manual-only
- `empty_result`: the extraction command ran but produced no usable body

The preflight classifier makes the separation explicit:

```bash
case "$source_category" in
  manual_only)
    state="unsupported"
    recovery_action="直接走手动入口"
    ;;
  optional_adapter)
    # classify missing adapter vs missing environment vs available
    ;;
esac
```

The runtime classifier keeps post-run handling on the same rail:

```bash
if [ "$exit_code" -ne 0 ]; then
  state="runtime_failed"
elif [ ! -f "$output_path" ] || ! grep -q '[^[:space:]]' "$output_path"; then
  state="empty_result"
else
  state="available"
fi
```

Then the repo reuses that helper in the two user-facing places that were most likely to drift:

1. `install.sh` now prints `summary-human` after environment checks, so installation ends with a clear adapter-by-adapter state summary.
2. `SKILL.md` now routes URL ingest through `check`, routes extraction results through `classify-run`, and tells the `status` workflow to include the same adapter-state summary.

Focused coverage in `tests/adapter-state.sh` now verifies the boundary directly:

- missing install vs unsupported source
- missing Chrome / missing `uv`
- runtime failure vs empty result
- install output includes the shared state summary
- skill instructions point ingest and status through the shared helper

The existing full regression suite still runs on top of that narrower check.

## Why This Works
The fix gives the repo one executable source of truth for optional adapter status instead of scattering similar rules across shell output and skill text. Because the helper reads the shared source registry and emits recovery actions together with fallback hints, install, ingest, and status all talk about the same problem in the same way.

That matters for Phase B because the product promise is not “all adapters always work.” The promise is “the core wiki path stays usable, and optional adapter failures are clearly contained.” The shared state model makes that boundary visible:

- core built-ins still go straight into the main flow
- optional adapters fail with a named state and a next step
- manual-only sources skip fake automation and go straight to manual input

## Prevention
- When adding a new optional source, do not stop at `source-registry.tsv`. Add its install/environment rules to `scripts/adapter-state.sh` so the state is executable, not just documented.
- Keep every adapter failure in one of the named states. If a new failure mode appears, either map it into the existing five-state model or add a new state deliberately across install, ingest, and status together.
- Run both checks before treating adapter work as complete:
  - `bash tests/adapter-state.sh`
  - `bash tests/regression.sh`
- Preserve the boundary that Phase B depends on: PDF, local documents, and pasted text must remain usable even if every optional adapter is unavailable.

## Related Issues
- Phase B plan: [2026-04-06-002-phase-b-core-and-adapter-separation-plan.md](../../plans/2026-04-06-002-phase-b-core-and-adapter-separation-plan.md)
- Task breakdown: [002-ready-p1-add-adapter-state-model-and-fallbacks.md](../../../.context/compound-engineering/todos/002-ready-p1-add-adapter-state-model-and-fallbacks.md)
- Requirements note: [2026-04-06-project-cleanup-and-restructuring-requirements.md](../../brainstorms/2026-04-06-project-cleanup-and-restructuring-requirements.md)
- Related but distinct compatibility work: [legacy-wiki-compatibility-without-forced-migration-2026-04-06.md](../workflow-issues/legacy-wiki-compatibility-without-forced-migration-2026-04-06.md)
- GitHub issues: none found with `gh issue list --search "adapter state fallback optional adapters" --state all --limit 5`
