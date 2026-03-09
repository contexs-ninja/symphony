# Project Audit Report — Symphony Elixir

**Date**: 2026-03-09
**Scope**: Full codebase audit (`elixir/` directory)
**Issue**: GitLab #2 — Project-wide inspection

## Summary

| Category | High | Medium | Low |
|----------|------|--------|-----|
| Performance | 1 | 2 | 1 |
| Interface | 1 | 1 | 1 |
| Edge cases | 1 | 2 | 1 |
| Structure | 1 | 1 | 1 |
| Authentication | 0 | 1 | 1 |
| Billing/Tokens | 0 | 1 | 1 |
| Synchronization | 0 | 1 | 1 |
| Orphan tasks | 0 | 1 | 1 |
| Orphan artifacts | 0 | 0 | 1 |
| **Total** | **4** | **10** | **9** |

## Fixed in This Audit

### [FIXED] P3 — completed MapSet unbounded growth (memory leak)
- **File**: `orchestrator.ex`
- `state.completed` grew without bound. Added `@max_completed_set_size` cap (500) with automatic eviction when exceeded.

### [FIXED] P1 — WorkflowStore reads file every second
- **File**: `workflow_store.ex`
- Added `quick_stamp/1` that checks only `mtime + size` via `File.stat`. Full content hash (`current_stamp`) is only computed when the quick stamp detects a change.

### [FIXED] I3 — Issue.blocked_by missing from typespec
- **File**: `linear/issue.ex`
- Added `@type blocker` and included `blocked_by: [blocker()]` in the `@type t` spec.

### [FIXED] M1 — Orphan firebase-debug.log
- Root `.gitignore` created to exclude `firebase-debug.log` and common editor/OS artifacts.

### [FIXED] E1 — Workspace identifier collision
- **File**: `workspace.ex`
- `safe_identifier` replaced non-alphanumeric chars with `_`, causing `issue/1` and `issue_1` to map to the same directory.
- Added hash suffix from `:erlang.phash2(raw)` when sanitization changes the identifier, ensuring unique workspace paths.

### [FIXED] E2 — AppServer turn timeout resets on every message
- **File**: `codex/app_server.ex`
- `receive_loop` used a relative `timeout_ms` in `after`, meaning any incoming message reset the clock. A turn could run indefinitely as long as the port kept sending data.
- Replaced with absolute deadline: `deadline_ms = System.monotonic_time(:millisecond) + timeout`. Each loop iteration computes `remaining_ms = max(0, deadline_ms - now)` for the `after` clause.

### [FIXED] P1 — Observability API has no authentication
- **Files**: `plugs/api_auth.ex` (new), `router.ex`
- Added `SymphonyElixirWeb.Plugs.ApiAuth` plug with opt-in Bearer token auth via `SYMPHONY_API_TOKEN` env var.
- When set, all `/api/v1/*` requests require `Authorization: Bearer <token>`. When unset, existing behavior preserved.

## Open Findings

### HIGH Priority

**S1-HIGH: Multiple files exceed 500-line limit**
- `status_dashboard.ex` (1,949), `orchestrator.ex` (1,457), `app_server.ex` (985), `config.ex` (938).
- Recommendation: Extract TokenAccounting, RetryScheduler, IssueDispatcher from orchestrator.

**I2-HIGH: Test helper functions in production modules**
- `orchestrator.ex:261-287`, `linear/client.ex:186-219` expose `*_for_test` functions.
- Recommendation: Move to test support modules.

### MEDIUM Priority

**P2: active_state_set/terminal_state_set recreated every poll cycle**
- `orchestrator.ex:564-576` — MapSet.new() called each cycle despite rare config changes.

**~~E2: AppServer turn timeout resets on every message~~ [FIXED]**
- Converted `receive_loop` from relative `timeout_ms` to absolute `deadline_ms` with `remaining_ms = max(0, deadline - now)`.

**~~E3: Port.command without error handling in AppServer~~ [FIXED]**
- Added try/rescue around `Port.command` in `send_message/2` to handle closed port gracefully.

**B1: Rate limits tracked but not enforced**
- `orchestrator.ex:1127-1137` — Rate limit data is displayed but dispatch continues regardless.

**Y1: TOCTOU between issue validation and dispatch**
- `revalidate_issue_for_dispatch` checks state, but it can change before actual dispatch.

**~~O1: Orphan workspaces between restarts~~ [FIXED]**
- Added periodic terminal workspace cleanup every 60 poll cycles (~30min) via `@workspace_cleanup_every_n_polls`.

**S2: Test coverage threshold is misleading**
- `mix.exs` claims 100% threshold but excludes 23 core modules.

### LOW Priority

**P4**: reconcile_running_issues makes N API calls for N running issues.
**E4**: `resolve_viewer_assignee_filter` failure blocks all polling with no fallback.
**A2**: No CSRF on API endpoints (acceptable for REST, but note browser-origin risk).
**B2**: Session restart could cause token double-counting.
**Y2**: `Workflow.set_workflow_file_path` + `maybe_reload_store` has a tiny race window.
**O2**: Workspaces not cleaned when issues are unassigned (non-terminal stop).
**S3**: No DDD bounded contexts; organized by technical layer only.
**X1**: `sh -lc` in workspace hooks uses login shell unnecessarily.
**X2**: Inline JavaScript in LiveView dashboard could conflict with CSP policies.

## Environment Constraints

- **Elixir not installed** on audit host: `mix test`, `mix credo`, `dialyzer` could not be executed.
- Runtime validation should be performed in CI.
