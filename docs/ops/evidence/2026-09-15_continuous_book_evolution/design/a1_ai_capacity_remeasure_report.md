# Slice report — `a1_ai_capacity_remeasure` (2026-09-15)

Directive: OWNER third directive `OWNER-DEC-D3-20260915` §2, §8, §9, §10, §36, §43A, §13 (record the OWNER decision),
§47. Verbatim: `docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_3_max_factory_utilization_verbatim.md`.

## What this slice does

1. **Re-measured AI capacity NOW** through the authoritative tools only (not cached snapshots), per §43A/§9. Ran a fresh
   `quota_pull.py`, `quota_governor.py` (dry-run + apply), `codex_budget_line.py` status, `kimi_governor.py evaluate`
   (real telemetry fetch), read `agy_quota.json`, and executed a single cheap `agy -p "Reply OK"` auth probe. No quota
   flag was hand-deleted; the owning governor reconciled them.
2. **Built `tools/strategy_farm/ai_capacity_readmodel.py`** → `D:/QM/reports/state/ai_capacity.json` (schema
   `qm.ai-capacity/v1`): per-provider models/tiers, contract_capabilities, enabled, auth_ok, routable_now, quota
   {window, used_pct, remaining_pct, reset_utc, hours_to_reset, source, measured_at_utc}, burn_rate_per_hour (from
   governor logs where derivable), pacing_state/flags, **shadow_price** (documented formula), independent_review_available,
   last_benchmark_utc=`EVIDENCE_MISSING`; plus fleet-level offload_opportunities (saturated + spare qualified pairs by
   capability, benchmark-gated for expansion caps) and review_independence (same_vendor_share from agent-chain receipts).
   Wired into `book_evolution_runner._default_state_builds` (append; `--no-render` so the Friday cut never writes the vault).
3. **`docs/ops/AI_FACTORY_CAPACITY_AND_ROUTING.md`** — hand-written CONTRACT section (providers, tiers, allowed
   capabilities, risk classes §6, routing §7/§8, pacing §9, review-independence §10, capability-expansion §5 + never-list)
   + a machine-generated CURRENT RUNTIME STATE block (idempotent marker replace) written by the same tool's `render`.
4. **Vault page** `02 Org/AI Factory Capacity & Routing.md` — same two-part structure (hand-written contract block +
   the same generated runtime block).
5. **`decisions/2026-09-15_owner_max_factory_utilization_eligibility_v2.md`** (id `OWNER-DEC-D3-20260915`): transcribes
   every decided item of directive 3 (§5 capability-expansion + never-list, §6–§10 routing/pacing/review, §11–§13 MT5
   throughput + **NO VPS UPGRADE / NO MIGRATION**, §14–§21 eligibility v2 + tail-risk contract + one-EA-cannot-destroy,
   §22 pattern filters, §23–§28 second-chance + PORTFOLIO_UTILITY_CHALLENGER, §29–§30 Fable derives thresholds via the
   counterfactual procedure, §31–§34 FTMO/DXZ priority + money signal, §35–§42 vault, §45 Mission Control, §47 authority)
   with supersedes + implementation-slice pointers and a measurement annex; REGISTRY.md row added; CLAUDE.md "Ratified
   Rules" dated annex appended (rest untouched).

## Re-measurement result (2026-09-15 ~17:4xZ, before → after)

| Provider | Weekly used | Remaining | Reset (UTC) | Flag before | After governor | Auth |
|---|---|---|---|---|---|---|
| Claude | 100% (hard ceiling) | 0% | 2026-09-17T22:00Z | `CLAUDE_DISABLED` (10:38Z) | HELD (warranted; not stale) | ok; interactive 5h=48% |
| Codex | 80% (+31.7pts ahead) | 20% | 2026-09-19T08:29Z | `CODEX_LOW_TOKENS` (09-12) | HELD; budget line within (target 92%) | ok |
| Antigravity | 14.5% used | 85.5% | ~21:2xZ (rolling) | none (no `AGY_LOW_QUOTA`) | none | ok — `agy -p` → `OK` exit 0 (OWNER relogged in) |
| Kimi (Allegro) | 0% (rolling_7d) | 100% | 2026-09-22T09:31Z | none | none (state NORMAL) | ok (managed usage endpoint) |

Key finding: the §2/§8 inefficiency is confirmed — Claude+Codex throttled while agy (85.5% spare) and Kimi (100% spare)
idle. The OWNER Claude top-up did **not** reduce the vendor's reported weekly utilization (still 100%); the interactive
orchestrator runs on the separate 5-hour window (48%). Both burn-authorization flags are expired and correctly ignored.
agy CLI auth is restored → cross-vendor critique/research offload to agy is available again (§10). Actionable-now
offloads: `research`/`strategy`/`summary` from Claude+Codex → agy/kimi (already in-contract). `code`/`tests`/`repo_edit`/
`ops` offloads are `benchmark_gated` (await slice b1 scorecard).

## Files changed

- `tools/strategy_farm/ai_capacity_readmodel.py` (NEW) — read-model generator + markdown render helper + CLI (`build`/`render`).
- `tools/strategy_farm/tests/test_ai_capacity_readmodel.py` (NEW) — 10 hermetic tests (fixtures, fixed clock).
- `tools/strategy_farm/book_evolution_runner.py` — one-line append to `_default_state_builds` (ai_capacity, `--no-render`).
- `docs/ops/AI_FACTORY_CAPACITY_AND_ROUTING.md` (NEW) — CONTRACT + generated runtime block.
- `decisions/2026-09-15_owner_max_factory_utilization_eligibility_v2.md` (NEW) — `OWNER-DEC-D3-20260915`.
- `decisions/REGISTRY.md` — active-family row.
- `CLAUDE.md` — dated `OWNER-DEC-D3-20260915` annex under "Ratified Rules (recent)".

## Contracts

- **`qm.ai-capacity/v1`** — `D:/QM/reports/state/ai_capacity.json`. Carries `schema` + `generated_at_utc`; deterministic
  (pure function of the read-only inputs + an injectable `now`); explicit `EVIDENCE_MISSING`/`UNKNOWN`/`NOT_EVALUATED`.
  Shadow-price formula documented in-file and in the module docstring: `sustainable_burn = remaining_pct /
  max(hours_to_reset, eps)`, `shadow_price = fleet_median / max(sustainable_burn, eps)` (>1 scarce, <1 spare), capped at
  9999 for a fully-exhausted provider; spare/saturated also honor absolute remaining headroom so a long-reset window
  (Kimi 7-day) does not misclassify a genuinely idle provider.

## Tests

`python -X utf8 -m pytest tools/strategy_farm/tests/test_ai_capacity_readmodel.py tools/strategy_farm/tests/test_book_evolution_readmodels.py -q`
→ **14 passed** (10 new ai-capacity + 4 book-evolution regression). Covers schema/provider set, quota+pacing, shadow-price
ordering (scarce>spare), offload (in-contract actionable vs expansion benchmark-gated), review independence, burn rate from
log, independent-review flags, last_benchmark EVIDENCE_MISSING, determinism (byte-identical), render idempotency, and
append-when-no-markers.

## Runtime / vault artifacts (with counts)

- `D:/QM/reports/state/ai_capacity.json` — 5 providers (claude, codex, agy, kimi, owner); 16 offload opportunities; 1
  completed critic chain (same_vendor_share 0.8 from prior receipts on the live box).
- `G:/My Drive/QuantMechanica - Company Reference/02 Org/AI Factory Capacity & Routing.md` — vault page (contract +
  generated runtime block), 1 file.
- Governor state re-reconciled by their own tools: `quota_governor_state.json`, `quota_snapshot.json`,
  `kimi_governor_state.json`/`kimi_quota_state.json`, `agy_quota.json`. No flag hand-edited.

## Rollback

Delete `ai_capacity_readmodel.py` + its test + `docs/ops/AI_FACTORY_CAPACITY_AND_ROUTING.md`, revert the one-line append
in `book_evolution_runner._default_state_builds`, remove `D:/QM/reports/state/ai_capacity.json` and the vault page. No
governor/router/gate/verdict/DB state is touched, so rollback is inert.

## NOT done (with reasons — belong to later directive-3 slices)

- **AI_CAPABILITY_BENCHMARK / AI_CAPABILITY_SCORECARD** (§4/§5) — slice b1. Until it lands, code/tests/repo_edit/ops
  offloads stay `benchmark_gated` and Kimi/agy keep their current contract capabilities (no expansion granted here).
- **Router capability + quota-aware routing changes** (§6/§7/§8 enforcement, §10 critic preference) — slice c1. This
  slice measures and documents; it does not modify `agent_router`/`agent_chain` routing.
- **Strategy eligibility v2 / tail-risk engine / pattern catalog / second-chance / PORTFOLIO_UTILITY_CHALLENGER**
  (§14–§32) — slices d1/e1/e2/f1/f2. Recorded as decisions; not implemented here.
- **VPS throughput / scheduling page** (§11/§12/§39) — slice g1. NO-VPS-UPGRADE decision recorded here (§13).
- **Live per-sleeve PnL attribution + FTMO first-passage model** (§33/§34) — slices h1/i1.
- **Remaining vault pages + §41 decision-grade mirror cadence / Mission Control efficiency widgets** (§37–§42/§45) —
  slices j1/d2. Only the AI Factory Capacity & Routing page (§36) is landed here.

## Exact commands for the orchestrator

Deterministic; no scheduled-task registration or worker reload is required for this slice (the generator is invoked by
the existing 15-min book-evolution state build once merged; a manual refresh is optional).

```
cd C:/QM/repo
# refresh the read-model + both markdown runtime blocks (safe, read-only inputs; writes ai_capacity.json + doc/vault blocks)
python -X utf8 tools/strategy_farm/ai_capacity_readmodel.py build
python -X utf8 tools/strategy_farm/ai_capacity_readmodel.py render     # docs + vault runtime blocks (idempotent)
# verify tests
python -X utf8 -m pytest tools/strategy_farm/tests/test_ai_capacity_readmodel.py -q
```

No task-map or worker change. The `book_evolution_runner` Friday cut runs it with `--no-render` automatically after
merge; the standalone `render` (docs + vault) is an orchestrator/operator step, not part of the frozen cut.
