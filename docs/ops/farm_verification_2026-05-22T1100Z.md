# Strategy-Farm Verification + Resolution Pass — 2026-05-22 11:00Z

Operator: Claude. Cadence: 4-hourly verification + resolution pass.
Evidence basis: `farmctl health`, `farmctl pipeline`, `farmctl repair`, `farmctl mt5-slots`,
`agent_router status`, direct reads of `farm_state.sqlite`.

## Status

Farm is **running and dispatching** — not down. One health invariant is FAIL
(`p_pass_stagnation`), and the farm's lead EA is stalled. No infrastructure outage.

- `farmctl health`: 18 OK / 1 FAIL / 0 WARN.
- `farmctl repair`: 0 anomalies (no stranded sources, no phantom review fails, no stale rows).
- MT5: 10/10 terminal-worker daemons alive; T3 + T9 actively running P2 backtests
  (QM5_10260 on NZDCHF.DWX / XNGUSD.DWX). 3 pending dispatch — low queue, not idle.
- Cards: card mining active (sources moving `active → cards_ready`, new cards approved).

## Findings

### 1. `p_pass_stagnation` FAIL — lead EA QM5_1056 stalled at P5 (INVALID)

Health reports "0 P3+ PASS verdicts in last 12h". Root cause is **not** infrastructure —
it is that the farm's most-advanced EA has stopped advancing:

- **QM5_1056** (`moskowitz-tsmom-multiasset` — Moskowitz/Ooi/Pedersen time-series
  momentum). P2/P3/P3.5/P4 all PASS. Last genuine PASS = P4 NDX.DWX at
  2026-05-21T16:17Z (~19h ago — just outside the 12h health window).
- Its P5 work-items: **33 PASS, 1 FAIL, 21 INVALID**. The most recent P5 attempt
  (2026-05-21T17:10Z, NDX.DWX) returned `INVALID` with **`evidence_path = NULL`** —
  no artifact captured for the failure, and no `events` rows for the P5 INVALIDs.
- `current_stage` for QM5_1056 still reads `P2_pass` despite P4 done + P5 attempted —
  stale stage label. This is what the `p2_pass_no_p3` check miscounts as
  "1 pending promotion".

Action needed (OWNER / Codex — not auto-fixable in this pass): investigate why P5
dispatch yields recurring `INVALID` verdicts and writes no evidence. Either the P5
phase is under-wired (evidence path not persisted) or NDX.DWX P5 runs are genuinely
producing uncomputable results. This is the single biggest pipeline blocker.

### 2. Zero-trade EA epidemic

- 47 EAs at `build_failed`; **35 of them = `zero_trade_smoke`** (build smoke produced
  zero trades).
- `events`: **QM5_1059** declared dead — `ea_dead_zero_trade_3x_rework_failed`,
  35/41 zero-trade failures (85% ratio), 2026-05-22T10:48Z.

This is a strategy-quality / card-quality signal, not an infra fault: a large share of
built EAs never trade. Worth a card-quality review (entry conditions too restrictive,
or timeframe/symbol mismatch) before more MT5 time is spent on the same card lineage.

### 3. Research router reservoir reads false-low

`research_backlog_inventory` reports `ready_approved_cards = 0` while
`cards_approved/` holds **1695 `.md` files**. Every one is counted "blocked" —
sampled blockers are all `schema_missing_body:*` (missing `thesis` / `falsification` /
`q08_q11_risks` / `implementation_notes`): old-format cards predating the tightened
9-section body schema, plus already-consumed cards that are never moved out of
`cards_approved/`.

Consequence: the research throttle (`min_ready_strategy_cards 5`) sees `ready=0`
permanently and keeps routing `research_strategy` tasks. Claude currently holds 3
zombie `IN_PROGRESS` tasks (2 `research_strategy`, 1 `review_strategy`) with
`created_at == updated_at` and no activity — they saturate Claude's `max_parallel=3`.
Nothing is starved yet (`claude_review_starved` = OK), so this is not acute, but the
reservoir calculation should exclude consumed/legacy cards or research routing will
stay falsely-on. Code fix for Codex.

### 4. QM5_1047 stale 3 days

`P4_pending`, last activity 2026-05-19T19:37Z. P4 verdict = `STRATEGY_FAIL` but stage
still `pending`; phase ordering is scrambled (P3 pending while P3.5 done). Its P3.5
`surviving_symbols` list also contains the same symbol repeated ~150× — a de-dup bug
in survivor recording. Recommend terminal-failing QM5_1047 and fixing survivor de-dup.

## Candidate critique — QM5_1056 (review-smoke deliverable)

QM5_1056 is the only EA near promotion, so it is the candidate critiqued this pass.

- **Concentration risk.** Card universe is FX + XAUUSD + NDX/WS30/GER40, but only
  **NDX.DWX survived** P3/P3.5/P4 (USDJPY and XTIUSD dropped after P2). A TSMOM EA
  that survives on a single index is effectively a single-instrument bet — it
  contradicts the mission's diversification-as-win-mechanism premise. Promoting it
  live would concentrate risk in one CFD index with overnight/weekend gap exposure.
- **P5 instability.** 21 INVALID against 33 PASS at P5 is a ~39% invalid rate. Even
  if P5 is later made to PASS, that instability should be explained before T_Live —
  an EA whose final-gate result flips between PASS and INVALID is not yet trustworthy.
- **Live-routability.** NDX.DWX is the intended live-routable index proxy (SP500.DWX
  is backtest-only) — that part is sound. But confirm NDX.DWX is routable on the live
  Darwinex Zero account before any T_Live manifest is prepared.

Verdict: **not promotion-ready.** Resolve the P5 INVALID root cause and the
single-symbol concentration question first.

## Resolution actions taken this pass

- Ran `farmctl repair` — idempotent, 0 anomalies applied.
- Verified MT5 saturation and dispatch — healthy, no orphan terminals.
- This document closes the routed `review_strategy` smoke task
  (`52db16da-1979-4974-b44e-9d0a43940353`).
- No task-DB surgery and no router-code changes performed — items 1, 3, 4 are
  OWNER/Codex decisions and are reported, not silently changed.

## Risks / blockers

- Pipeline cannot produce a P5+ PASS until QM5_1056's P5 INVALID cause is found —
  promotion flow is blocked at the farm's leading edge.
- Zero-trade epidemic will keep consuming MT5 time on non-trading EAs until card
  entry-logic quality is addressed.

## Recommended next steps (OWNER / Codex)

1. Codex: investigate P5 dispatch — why `INVALID` with `evidence_path = NULL`; persist
   P5 evidence so failures are diagnosable.
2. Codex: fix `research_backlog_inventory` to exclude consumed/legacy cards so the
   research throttle reflects true reservoir depth.
3. Codex: terminal-fail QM5_1047; fix `surviving_symbols` de-dup.
4. Claude (next pass): card-quality review of the zero-trade EA lineage before
   re-queuing similar cards.
