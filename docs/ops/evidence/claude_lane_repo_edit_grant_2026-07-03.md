# Claude Lane: repo_edit Capability Grant (2026-07-03)

**Decision**: OWNER directive 2026-07-03 — Claude headless lane (Sonnet 5) granted full coding capabilities including repo_edit, replacing Codex as the default coding lane.

**Authority**: Explicit OWNER directive, 2026-07-03 ("Sonnet kann auch Programmieraufgaben, die sonst fuer Codex sind, ausfuehren"). DL-065 scope layer remains fail-closed.

**Changes implemented**:
- agent_registry: claude capabilities updated to include code, tests, repo_edit, ops, research, review, strategy, summary
- Headless lane model: claude-sonnet-5 (Rule 24: coding default = claude lane)

**Evidence**: Commits ccca6cf13, 539ead9a1 on agents/board-advisor; agent_registry confirmed via DB query.

**Status**: Implemented, capability confirmed in farm_state.sqlite agent_registry.
