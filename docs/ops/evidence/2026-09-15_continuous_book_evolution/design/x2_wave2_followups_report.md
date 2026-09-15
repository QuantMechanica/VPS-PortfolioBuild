# Slice x2_wave2_followups — wave-2 review follow-ups + one telemetry fix

Date: 2026-09-15. Authority: OWNER-DEC-CBE-20260915 (wave-2 reviews E1/F1/G1/D1 + Kimi
telemetry). Branch `agents/board-advisor` (worktree). Slice key `x2_wave2_followups`.

Addresses the MAJOR items of the wave-2 reviews (e1/f1/g1/d1) plus the Kimi 15-min-token
telemetry gap. Six independent changes; all tests green.

## (1) E1 M1 — recompose FTMO readiness capture moved into freeze

`recompose.py evaluate` read the live `ftmo_challenge_readiness.json` at evaluate time, so
an evaluation was not a pure function of the frozen snapshot (a change to the live file
between freeze and evaluate could alter the result).

- `frozen_snapshot.freeze` now captures the F1 readiness read-model at freeze time
  (`_ftmo_readiness_capture`): the file is copied byte-for-byte into `inputs/` with its
  sha256 pinned, and the `demo_cycle` + recommendation are embedded in the manifest under
  `ftmo_readiness`. `load_snapshot` re-hashes the captured file (section 70 fail-closed).
- `recompose._ftmo_demo_cycle(manifest)` now reads ONLY the snapshot manifest, never the
  live file.
- New arg `readiness_state` on `freeze` for injectable testing.
- Test `test_evaluate_byte_identical_across_change_to_live_readiness`: freeze → evaluate →
  change the live file → evaluate again → byte-identical read-model, demo_cycle unchanged.
  Test `test_load_snapshot_rehashes_readiness_capture`: tampering fails closed.

## (2) E1 M2 — risk diagnostics for the selected + every alternative; dependence weighed as downside risk

Previously `risk_diagnostics` was computed only for the incumbent baseline.

- `recompose.evaluate` now computes `_risk_diagnostics` for EVERY assessed alternative
  roster (advisory cap warnings + hard guards + dependence panel incl. downside correlation
  and entry-day trade overlap) and attaches it to each `alternatives_assessed` entry and to
  the read-model proposal (`selected_alternative_risk_diagnostics`).
- New `_change_concentration`: an advisory, non-blocking warning when a change RAISES a
  symbol's exposure (names the symbol + its share of the risk budget). This is a measured
  observation, NOT a new permanent cap (directive sec 8).
- `materiality.assess` gains a `dependence_risk` factor (documented in `materiality.py`):
  the surviving HARD portfolio guard (joint-tail/data) must pass and measured downside
  correlation must not worsen beyond `max_downside_corr_worsening` (0.10); advisory
  label-concentration increases are recorded but non-blocking. Folded into `material`.
- `evidence.md` gains a "Selected / proposed alternative risk diagnostics" section.

**2026-W38 DXZ re-run (real snapshot `D:/QM/reports/book_evolution/2026-W38/dxz/snapshot`):
outcome UNCHANGED = ADD_SLEEVE (add 10700 XAUUSD).** The XAUUSD concentration warning now
shows explicitly:
`XAUUSD: change raises book exposure to XAUUSD from 2.3939% to 2.4714% (already the largest
symbol) (share of budget 22.47%)`. Dependence risk: hard_guards_passed=true,
Δmean|downside-corr|=+0.0005 (band 0.10) → pass=true, so the change is not blocked; the
advisory concentration is surfaced, not suppressed. Live `book_evolution_dxz.json`,
`evaluation.json` and `evidence.md` regenerated with the M2 diagnostics.

## (3) F1 M1+M2 — readiness metric-name alignment + worst-across-cycles

- `challenge_readiness.py` metrics now carry the shared-contract names `trade_density_per_day`
  and `swap_cost`, with the old `trade_density_entry_days` / `swap_cost_usd` kept as aliases.
- Added worst-across-cycles risk metrics `max_dd_pct_worst_cycle` /
  `worst_daily_loss_pct_worst_cycle` next to the current-cycle ones. Rebuilt read-model shows
  `max_dd_pct=-0.29%` (latest, benign) but `max_dd_pct_worst_cycle=-10.26%` — the breach an
  earlier cycle produced is no longer hidden by a benign latest cycle.
- `D:/QM/reports/state/ftmo_challenge_readiness.json` + `docs/ops/FTMO_CHALLENGE_READINESS.md`
  rebuilt (recommendation still NOT_READY).

## (4) G1 MAJOR-1+2 — successor artifact QM-RESEARCH-2026-0002 with the real H-CW card

The sealed `QM-RESEARCH-2026-0001` had boilerplate mechanized H1/H2/H3 cards and NO card for
the campaign's surviving candidate H-CW. The sealed artifact was NOT edited; a successor was
minted (lineage `parent_version_id=QM-RESEARCH-2026-0001`, version 2, author
`multi-agent:Kimi+Fable` per the authorized-author config).

- New `research/campaign_ftmo_gap_cards_v2.py`: the H-CW mechanizable card (cash-window index
  continuation, session-flat, NDX/GDAXI/SP500 H1 — long/short entry, no-trade, exit, stop,
  take-profit, session rules, filters, bounded parameter ranges, timeframe, symbols, expected
  frequency, invalidation, kill criteria, from the campaign kimi_answer + critique) and the
  truthful H1/H2/H3 finding cards (H1 inconclusive, H2 analytical/non-mechanizable, H3 not
  established).
- New `research/finalize_ftmo_gap_campaign_v2.py`: remints, writes numeric-provenance result
  files + observe manifest, runs `mechanization_check` on each card (H-CW PASS; findings
  RETURN_TO_RESEARCH — honest), runs the cross-vendor critique via `agent_chain` (gated 2026-
  09-15 → honest Fable inline non-Kimi fallback, verdict REVISE, cross_vendor, caveat that
  Fable co-authored recorded), seals (status reviewed), verifies, updates experiment_memory +
  search_history + research_state, writes the receipt.
- Ran for real: `QM-RESEARCH-2026-0002` sealed, `research_source.verify` ok=true
  (sha256 `f6d39a23…`). Parent 0001 unchanged (git clean). `.gitattributes` seal rule
  (`QM-RESEARCH-*/** -text`) kept and confirmed to cover 0002 (`git check-attr text` → unset).
- Receipt: `docs/ops/evidence/2026-09-15_continuous_book_evolution/research/CAMP-2026-0001_followup_receipt.md`.

## (5) D1 major — heartbeat renders the four book-evolution health keys

- `heartbeat_snapshot.py` new `probe_book_evolution_health` reads
  `D:/QM/reports/state/book_evolution_health.json` and surfaces `book_evolution_readmodels`,
  `ftmo_readiness_recommendation`, `research_state_freshness`, `factory_bottleneck_top` in a
  new "## Buchentwicklungs-Gesundheit" vault-Heartbeat section; RED read-models or STALE
  research raise a flag; a missing read-model is EVIDENCE_MISSING (no crash).
- Test `test_heartbeat_book_evolution_health.py` (fixture): renders the four keys; missing
  read-model degrades; RED/STALE raise flags.

## (6) Kimi telemetry — bounded token refresh

The OAuth token is a 15-min rolling token, so the 15-min governor fetch mostly returned
`auth_error`.

- `kimi_quota_fetcher.py` + `config/kimi_quota_fetcher.v1.json`: `refresh.via_cli=true` by
  default with `min_interval_s=21600` (6h). `refresh_allowed()` gates the single cheap CLI
  call on a stale token AND last-successful-fetch age ≥ min_interval AND last-refresh age ≥
  min_interval (a successful fetch resets the clock → ≤4 refresh calls/day; a separate
  `refresh_last_utc` guard stops a failing refresh from looping). Each refresh is counted in
  `refresh_calls` in the state file and recorded in the usage ledger with role
  `quota_refresh`. Never logs/prints/persists the token.
- Tests: interval guard (`test_refresh_allowed_gated_by_last_success`,
  `test_stale_token_recent_success_does_not_spawn_refresh`,
  `test_stale_token_old_success_spawns_bounded_refresh_and_records`) + never-print-token
  invariant (`test_refresh_never_leaks_token_in_state_or_ledger`).
- Ran `kimi_governor.py evaluate` once after: **usage_source = `managed_usage_endpoint`**,
  quota_fetch_status ok, refresh_calls=1 (one bounded refresh fired, real telemetry), a
  `quota_refresh` ledger line appended, no token in the state file.

## Files changed
- `tools/strategy_farm/portfolio/recompose/frozen_snapshot.py` (readiness capture + verify)
- `tools/strategy_farm/portfolio/recompose/recompose.py` (per-alt diagnostics, change-conc,
  selected-alt read-model, evidence.md, snapshot-only demo_cycle)
- `tools/strategy_farm/portfolio/recompose/materiality.py` (dependence_risk factor)
- `tools/strategy_farm/ftmo/challenge_readiness.py` (metric names + worst-across-cycles)
- `tools/strategy_farm/heartbeat_snapshot.py` (book-evolution health probe + render)
- `tools/strategy_farm/kimi_quota_fetcher.py` + `config/kimi_quota_fetcher.v1.json` (bounded refresh)
- `tools/strategy_farm/research/campaign_ftmo_gap_cards_v2.py` (new; H-CW + findings)
- `tools/strategy_farm/research/finalize_ftmo_gap_campaign_v2.py` (new; successor driver)
- `strategy-seeds/sources/QM-RESEARCH-2026-0002/**` (new sealed successor artifact)
- `docs/ops/FTMO_CHALLENGE_READINESS.md` (regenerated), receipt (new)
- Tests: `test_recompose_engine.py` (+stale-F1 fix), `test_ftmo_challenge_readiness.py`,
  `test_heartbeat_book_evolution_health.py` (new), `test_kimi_quota_fetcher.py`,
  `test_research_campaign_v2.py` (new)

## Contracts changed / added
- `qm.recompose-frozen-inputs/v1` — manifest gains `ftmo_readiness` (capture block).
- `qm.recompose-evaluation/v1` / `qm.book-evolution-venue/v1` — per-alternative
  `risk_diagnostics` + proposal `selected_alternative_risk_diagnostics` (+ change-concentration).
- `qm.recompose-materiality/v1` — new `dependence_risk` factor.
- `qm.ftmo-challenge-readiness/v1` — canonical `trade_density_per_day` / `swap_cost` +
  aliases + `*_worst_cycle` metrics.
- `qm.kimi-quota/v1` — state gains `refresh_calls` / `refresh_last_utc`.
- `qm.internal-research-source/v1` (0002 instance, sealed; lineage parent 0001) +
  `qm.kimi-usage/v1` role `quota_refresh`.

## Tests + summary line
`python -X utf8 -m pytest tools/strategy_farm/tests/test_recompose_engine.py
tools/strategy_farm/tests/test_ftmo_challenge_readiness.py tools/strategy_farm/tests/test_ftmo_fitness.py
tools/strategy_farm/tests/test_heartbeat_book_evolution_health.py
tools/strategy_farm/tests/test_kimi_quota_fetcher.py tools/strategy_farm/tests/test_kimi_governor.py
tools/strategy_farm/tests/test_research_campaign.py tools/strategy_farm/tests/test_research_campaign_v2.py
tools/strategy_farm/tests/test_research_source.py -q` → **114 passed**.
Neighbour suites (factory_bottleneck / mission_control_v2 / book_evolution_readmodels /
ftmo_demo_cycle / research_ledgers / concentration_tail / dxz_next_book_trigger /
book_build_guard) → **86 passed**.

## Runtime artifacts written (real data)
- `strategy-seeds/sources/QM-RESEARCH-2026-0002/**` (sealed; verify ok, sha256 `f6d39a23…`)
- `D:/QM/research/campaigns/CAMP-2026-0001-ftmo-gap/` — `campaign.json` (updated to successor),
  `campaign_finalize_v2.json`, `critique_claude_v2.md`
- Appended: `experiment_memory_ledger.jsonl` (H-CW/H1/H2/H3 + negative finding, artifact 0002),
  `search_history_ledger.jsonl` (cash-window-index-continuation), `research_source_ledger.jsonl`
  (mint+seal 0002), `kimi_usage_ledger.jsonl` (quota_refresh)
- `D:/QM/reports/state/research_state.json` refreshed
- `D:/QM/reports/state/book_evolution_dxz.json` + `D:/QM/reports/book_evolution/2026-W38/dxz/`
  (evaluation.json + evidence.md) regenerated with M2 diagnostics
- `D:/QM/reports/state/ftmo_challenge_readiness.json` + `docs/ops/FTMO_CHALLENGE_READINESS.md`
  rebuilt; `D:/QM/reports/state/kimi_quota_state.json` (refresh_calls=1, usage_source managed)

## Rollback
- Revert the modified files; delete the two new `research/*_v2.py`, the new tests, and (only
  if a clean state is wanted) the additive read-models under `D:/QM`. The sealed
  `QM-RESEARCH-2026-0002` is an append-only versioned artifact — supersede via
  `research_source.remint`, never edit in place. The Kimi refresh has a kill switch
  (`refresh.via_cli=false` in the config, or env `QM_KIMI_QUOTA_FETCH=0`).

## NOT done (with reasons)
- **FTMO W38 snapshot re-freeze:** the existing FTMO W38 snapshot predates the readiness
  capture, so re-evaluating it now yields `demo_cycle=EVIDENCE_MISSING` (honest — that snapshot
  did not capture it). The live `book_evolution_ftmo.json` was left as-is (still carries the
  demo_cycle from its original evaluate). Orchestrator action: re-`freeze --venue ftmo` then
  `evaluate` to restore a captured demo_cycle going forward.
- **Independent spawned non-Kimi critic for 0002:** the automated agent_chain lanes were all
  quota-gated 2026-09-15 (CLAUDE_DISABLED / CODEX_LOW_TOKENS / AGY_LOW_QUOTA), so the critique
  fell back to Fable inline (non-Kimi, cross-vendor) with the honest caveat that Fable co-
  authored the mechanization. Re-run `finalize_ftmo_gap_campaign_v2.py` (or an agent_chain
  attack) once a critic lane is off quota-hold to corroborate the REVISE with an independent
  seat.
- **No scheduled-task registration:** installer/wiring changes are documented; the orchestrator
  registers tasks.

## Commands the orchestrator must run
1. Commit the staged changes with explicit pathspecs (orchestrator commits; the sealed
   0002 store files must be committed byte-exact — `.gitattributes -text` keeps LF).
2. (Optional, to restore FTMO demo_cycle in the read-model) re-freeze + evaluate FTMO:
   `python tools/strategy_farm/portfolio/recompose/recompose.py freeze --venue ftmo --out <snap>`
   then `... evaluate --venue ftmo --snapshot <snap> --out D:/QM/reports/state/book_evolution_ftmo.json`.
3. No new scheduled task required for the Kimi refresh (wired into `kimi_governor.py evaluate`,
   which the existing `QM_StrategyFarm_KimiGovernor_15min` task already runs).
