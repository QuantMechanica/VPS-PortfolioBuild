# Adversarial review — slice `a1_ai_capacity_remeasure`

- Reviewer: adversarial reviewer (read-only except this file)
- Date: 2026-09-15
- Patch: `C:/Users/ADMINI~1/AppData/Local/Temp/1/claude/C--QM-repo/15a7ddd6-2faa-4bee-8808-c948b4dcd647/scratchpad/patches_d3/a1_ai_capacity_remeasure.patch`
- Repo HEAD reviewed: `1617cb22be689974139272d8dc8afe8d2617fb4a` (branch `agents/board-advisor`)
- Directive: `OWNER-DEC-D3-20260915` §2/§8/§9/§10/§36/§43A/§13/§47

## Verdict: ACCEPT

A documentation + read-only read-model + decision-record slice. `git apply --check` clean, 14 tests pass,
artifacts are real, deterministic, idempotent, and honest. No RED boundary crossed.

## Checks performed

### git apply --check
`git apply --check` against HEAD → EXIT 0 (no conflicts). Full apply → `git apply -R` round-trip verified
clean (patch files absent from tree afterward; working tree restored).

### Tests
Applied patch transiently, ran
`pytest tools/strategy_farm/tests/test_ai_capacity_readmodel.py tools/strategy_farm/tests/test_book_evolution_readmodels.py -q`
→ **14 passed** (10 new ai-capacity + 4 book-evolution regression), then reverted. Covers determinism
(byte-identical), render idempotency, shadow-price ordering, offload in-contract-vs-benchmark-gated, review
independence, burn-rate-from-log, `last_benchmark_utc=EVIDENCE_MISSING`, append-when-no-markers.

### Honesty of numbers (cross-checked against live governor state)
- **Claude 100% / reset 2026-09-17T22:00Z / 5h=48% / flag HELD** — confirmed in
  `D:/QM/reports/state/quota_governor_state.json` (`used_pct 100.0`, `action hold`, why "hard ceiling",
  burn flag expired 2026-08-24 → normal pacing). Honest.
- **Codex 80% / +~31.5pts ahead / reset 2026-09-19T08:29Z / flag HELD** — confirmed (`used_pct 80.0`,
  `diff 31.5`, `action hold`, burn flag expired 2026-08-25). Report says "+31.7pts"; state says 31.5 — immaterial.
- **agy binding remaining 85.5% (at 17:51Z)** — `agy_quota.json` carries a real `binding_remaining_pct` field;
  live value at 18:00Z is 78.2% (agy being consumed → remaining dropped). Consistent runtime drift, not fabrication.
  `ok:True token_expired:False`, token valid to 20:26Z corroborates restored agy auth.
- **Both burn-authorization flags present-but-expired and correctly ignored** — confirmed on disk
  (`CLAUDE_BURN_AUTHORIZED.flag`/`CODEX_BURN_AUTHORIZED.flag`, Aug dates); `_flag_info` parses `expires_at` →
  `burn_authorized=False`. No flag hand-deleted (governor `owned:true` reconciliation). Honest.
- **No `AGY_LOW_QUOTA.flag` / `KIMI_LOW_QUOTA.flag` on disk** — matches read-model (agy/kimi `NORMAL`, not gated).
- Read-model uses explicit `EVIDENCE_MISSING`/`UNKNOWN`/`NOT_EVALUATED` for missing inputs (no zero-forging);
  `review_independence.same_vendor_share=0.8` with `degraded=True` is honest self-reporting of a real problem.

### RED-touch grep — none crossed
- **Gate/verdict semantics:** unchanged. Read-model has no verdict-write path; `agent_router.py`
  `DEFAULT_AGENT_REGISTRY` is NOT modified by the patch.
- **Economic/selection thresholds:** none changed. §30 counterfactual authority is only *recorded* — decision
  record states "No threshold is changed by this record"; DL-089 selection rule kept ROT. Shadow-price constants
  (SATURATED/SPARE 1.5/0.67, remaining 25/50) are advisory routing heuristics in a read-model, not gate/selection
  economics.
- **T_Live / FTMO terminal / AutoTrading / purchase / live deployment:** untouched.
- **Sealed/dated artifacts:** new decision file (new); `REGISTRY.md` gets a row *added*; `CLAUDE.md` "Ratified
  Rules" gets an *appended* annex (explicitly required by the task); verbatim directive not edited.
- **Farm DB writes:** none. Read-model reads JSON state/config/flags/receipts; writes only
  `D:/QM/reports/state/ai_capacity.json` + (on operator `render`) the doc/vault runtime blocks.
- **Secrets in docs/vault/json:** clean (only match was the `CODEX_LOW_TOKENS.flag` filename). Read-model extracts
  only `binding_remaining_pct/reset/checked_at` from `agy_quota.json`, never the token.
- **Provider grants beyond §5:** none. `EXPANSION_CAPABILITIES` (code/tests/repo_edit/repo/ops/
  scalpel_mechanization) are only *labeled* `benchmark_gated`; no registry capability change; never-list preserved
  in doc + decision.
- **Unbounded recovery:** N/A (decision record mandates deterministic risk contracts).
- **Scheduler starve/double-claim:** the `book_evolution_runner._default_state_builds` append is a sequential,
  read-only subprocess (300s timeout, `check=False`, exception-isolated) with `--no-render` so the Friday cut never
  writes the vault. No claim/lease/queue/DB interaction. Regression tests green.

### Artifacts on disk
- `D:/QM/reports/state/ai_capacity.json` (`qm.ai-capacity/v1`, 5 providers, 16 offloads, review share 0.8) — real,
  carries `schema` + `generated_at_utc`.
- Vault `02 Org/AI Factory Capacity & Routing.md` — present, two-part (§36): `## CONTRACT` + `## CURRENT RUNTIME
  STATE` with idempotent generated markers.
- Docs page runtime block matches the JSON (internal consistency).

## Minor notes (non-blocking)
1. **Snapshot staleness / manual render.** The committed JSON (17:51Z) and the rendered doc/vault runtime blocks
   show kimi 100% routable / agy 85.5%, but live state at 18:00Z shows agy 78.2% and kimi
   `quota_fetch_status=auth_error` (`real_quota=null` → a fresh `build` would emit kimi `EVIDENCE_MISSING`).
   The Friday cut runs `build --no-render`, so the human-facing doc/vault blocks only refresh on an operator
   `render` — they can drift. Recommend scheduling `render` or documenting the manual step (the slice report does
   note it).
2. **Kimi auth fragility.** `auth_ok` keys off `quota_fetch_status=="ok"`; the managed endpoint is intermittently
   auth_error (live: fallback to local ledger, week 1.2% used vs real_quota 0%). The "Kimi 100% spare" offload
   conclusion is therefore fragile — worth carrying into slice c1 routing so an auth_error moment doesn't route
   work to an unreachable lane. Read-model behaviour itself is honest (emits EVIDENCE_MISSING when real_quota
   absent).
3. **Verification limit.** The 17:51Z kimi/agy state files were overwritten by the 18:00Z governor cycle, so the
   exact measurement-time inputs could not be re-inspected; the committed values are consistent with the read-model
   code paths and there is no sign of hand-editing.
4. **Large sealed decision surface.** The decision record transcribes many later-slice decisions as BINDING/FINAL,
   but each carries an explicit "LATER SLICE" pointer and no implementation — this is exactly what the task asked
   for and is safe.
