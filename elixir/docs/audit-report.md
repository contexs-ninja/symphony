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

## Open Findings

### HIGH Priority

**P1-HIGH: Observability API has no authentication**
- Files: `router.ex:30-39`, `observability_api_controller.ex`
- All API endpoints (`/api/v1/state`, `/api/v1/refresh`) and the LiveView dashboard have zero auth.
- Default bind to `127.0.0.1` mitigates local risk, but any `0.0.0.0` binding exposes orchestrator state.
- Recommendation: Add Bearer token or IP whitelist middleware.

**E1-HIGH: Workspace identifier collision**
- File: `workspace.ex:115-117`
- `safe_identifier` replaces non-alphanumeric chars with `_`, so `issue/1` and `issue_1` map to the same directory.
- Recommendation: Use hash suffix or percent-encoding.

**S1-HIGH: Multiple files exceed 500-line limit**
- `status_dashboard.ex` (1,949), `orchestrator.ex` (1,457), `app_server.ex` (985), `config.ex` (938).
- Recommendation: Extract TokenAccounting, RetryScheduler, IssueDispatcher from orchestrator.

**I2-HIGH: Test helper functions in production modules**
- `orchestrator.ex:261-287`, `linear/client.ex:186-219` expose `*_for_test` functions.
- Recommendation: Move to test support modules.

### MEDIUM Priority

**P2: active_state_set/terminal_state_set recreated every poll cycle**
- `orchestrator.ex:564-576` — MapSet.new() called each cycle despite rare config changes.

**E2: AppServer turn timeout resets on every message**
- Turns can exceed the 1-hour limit as long as messages keep arriving.

**E3: Port.command without error handling in AppServer**
- `Port.command(port, line)` can raise if the port is already closed.

**B1: Rate limits tracked but not enforced**
- `orchestrator.ex:1127-1137` — Rate limit data is displayed but dispatch continues regardless.

**Y1: TOCTOU between issue validation and dispatch**
- `revalidate_issue_for_dispatch` checks state, but it can change before actual dispatch.

**O1: Orphan workspaces between restarts**
- Terminal-state cleanup only runs at startup; no periodic GC.

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
