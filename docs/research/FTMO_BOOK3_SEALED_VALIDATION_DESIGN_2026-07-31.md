# FTMO Book3 — Sealed Validation Design v1 (Claude, 2026-07-31)

Goal: lift Book3 (**R0 = 9936/USDJPY, R1 = 10145/XAUUSD, R2 = 13108/XTIUSD**)
from `strict_qualification: UNVERIFIED` to gate-eligible — i.e. turn the
2026-07-30 temporal-holdout diagnostic (two-phase pass 81.37 %, official breach
3.92 %, 102 starts; `docs/ops/evidence/2026-07-30_ftmo_book3_research_only_runtime_projection.json`)
into a **selection-sealed, event-complete proof** or an honest refutation.

The four blockers recorded in
`2026-07-30_ftmo_book3_strict_qualification_unverified.json`:
1. missing authenticated strict-Q08 artifact per sleeve,
2. missing event-complete joint-equity trace,
3. no selection-sealed OOS,
4. no exact-profile free trial.

This design addresses (2) and (3) fully, (1) as a work item with an explicit
OWNER question, and declares (4) out of scope (money gate = OWNER; a demo needs
no fees but its scheduling is an OWNER call — FTMO account is PARKED to
2026-08-25 anyway).

## Non-goals / hard constraints

- **No gate redefinition.** `challenge_ready` and Q08 semantics stay as they
  are. If a sleeve's authenticated Q08 lands FAIL_SOFT, that is surfaced as an
  OWNER decision question (DL), never silently accepted.
- **No 20181 / joint-EA route.** The OnTimer joint EA failed the fidelity bound
  (5 s median exit shift, 16.15 % shifted exits — binding error bar, 2026-07-31)
  and the corpus comparison showed only 20/275 economically identical rows.
  Input = **native standalone Q08 aggregate streams** only.
- **No invented costs.** FTMO commission/swap only from `venue_cost_model.json`;
  if a required rate is absent, the verdict blocks on that field
  (`money_gate: SETUP_DATA_MISSING` persists) rather than estimating.
  Note 10145/XAUUSD holds overnight — swap injection is mandatory for it; the
  10128+10145 book died on exactly this (swap 29x commission).

## Component 1 — Pre-registration seal

A committed JSON (`docs/ops/evidence/<date>_book3_seal.v1.json`, plus `.sha256`)
frozen **before** any evaluation run, containing:

- Composition: the three sleeves, their exact stream artifact paths + SHA256.
- Per-sleeve risk multipliers, **derived only from data up to the seal
  boundary** (proposal: boundary `2022-09-01`, matching the established IS/OOS
  discipline; selection tooling may only read bars/trades before it).
- Overlay: off (measured 07-27: overlays cost the sprint upside).
- Phase rules pinned: P1 +10 % / P2 +5 %, daily −5 % (CE(S)T day boundary),
  total −10 %, trading-day = position opened, target requires closed positions.
- Metrics + acceptance pinned: primary = two-phase pass probability on the
  holdout with **CI lower bound >= 0.80** (CI method: moving-block bootstrap on
  start dates; block length from significant autocorrelation lag — reviewer
  challenge welcome), secondary = official breach rate, censoring reported.
- Simulator identity: tool name + git commit; evaluation window
  `[2022-09-01, last complete month]`, single shot.
- **n_trials ledger:** this seal is attempt #1. Any re-seal (changed
  composition, multipliers, thresholds) increments the counter and is reported
  in every subsequent verdict — no silent retry-until-pass.

## Component 2 — Event-complete shared-equity trace

The known failure class is close-day bucketing (`challenge_final.py:110`
discarded `entry_time`; multi-day positions were invisible intraday). The trace
must therefore be built at **event granularity**:

- Inputs per trade: `entry_time`, `close_time`, `net`, `mae_acct` (all present
  in the durable Q08 aggregate streams). **Precondition:** 100 % `entry_time`
  coverage on all three streams — verify first; if any stream lacks it,
  regenerating that stream is a blocking work item (119/189 streams carry
  entry_time; these three must be confirmed, not assumed).
- Build a merged event timeline (all opens/closes across the three sleeves at
  the seal's multipliers) and evaluate the daily-loss rule **twice**:
  - optimistic bound: realized close-only equity;
  - pessimistic bound: every open position simultaneously at its `mae_acct`
    (physically impossible, strictly conservative).
  A start passes only if it passes on the **pessimistic** bound for breach and
  on realized equity for target. Both bounds are reported (the 07-27 precedent:
  3 accounts 83.3 % / 81.1 % — verdict must not hang on the unmodeled term).
- Day boundaries in CE(S)T (FTMO reset), not UTC. Multi-day positions count on
  every open day. Margin sanity per FTMO leverage table (FX 1:100, indices
  1:50, metals 1:30) as a reported diagnostic, not a pass criterion.

## Component 3 — Authenticated strict-Q08 per sleeve

Current DB state: 9936 Q08 = FAIL_SOFT (07-27), 10145 = re-run evidence only,
13108 = research-only. Work item: obtain a Q08 verdict on the **exact current
binary** with the evidence chain newer than the binary (vintage doctrine).
Where the result is FAIL_SOFT: per DL-082 §3c FAIL_SOFT promotes to Q09, but
`challenge_ready` historically required strict PASS — **OWNER question, to be
asked explicitly when results are in:** does FAIL_SOFT (EDGE_SOFT/LOW_SAMPLE
tier) qualify a sleeve for a *demo* book while strict PASS remains required for
paid? This design does not decide it.

## Component 4 — Tool

`tools/strategy_farm/portfolio/book3_sealed_eval.py`:

- Pure function of (seal JSON, stream files): deterministic, no DB writes,
  read-only against `farm_state.sqlite` (verdict cross-check only).
- Refuses to run if seal SHA mismatch, streams' SHA mismatch, entry_time
  coverage < 100 %, or required venue-cost fields missing (fail-closed).
- Emits: verdict JSON (both bounds, CI, censoring, n_trials, blocker list) +
  event-level trace CSV for audit.
- Tests: fabricated fixtures incl. (a) a multi-day position that breaches
  intraday but closes green (must fail pessimistic bound), (b) CE(S)T boundary
  case, (c) seal-mismatch refusal, (d) missing-swap refusal.

## Expected outcome (honesty clause)

The sealed number will likely be **lower** than the 81.37 % diagnostic (that
number saw the whole corpus). If the CI lower bound lands < 0.80: Book3 is not
ready, and the verdict artifact feeds the sleeve-breeding target instead
(FUND_SCORE >= 1.0; current pool max 0.41) — that outcome is a success of the
method, not a failure of the programme.

## Open questions for review (R1)

1. CI method: moving-block bootstrap vs Newey-West on start-window outcomes —
   which, and what block length rule?
2. Seal boundary 2022-09-01: right cut given 13108's stream history (548
   trades — enough post-boundary starts)?
3. Multiplier freeze source: which existing IS artifact pins the three
   multipliers, or must a small IS-only optimizer run pre-seal (then its code +
   inputs are part of the seal)?
4. Stream provenance: R1/R2 native streams come from the Book3-R1/R2 native
   reconcile runs (291 / 548 trades) — are those the durable aggregate streams
   or per-run copies? Trade-count matching per `build_joint_sim_manifest.py`
   doctrine (Common\Files had 155 vs 433 once — never trust path convention).
5. Swap model for XTIUSD (13108) under FTMO — present in venue_cost_model.json?
