# Cards-review G0 adjudication — wave 2 (+ 3 wave-1 reopens)

Date: 2026-08-21
Authority: OWNER drain directive, routed by Claude; wave rubric adds a third
outcome (RESPECIFY) that OVERRIDES the standard approve/reject-only bootstrap.
Criteria: `processes/qb_reputable_source_criteria.md` (R1–R4), strict-R2 reading
per this wave. Respecification style: `docs/ops/evidence/471cffc3_strategy_cards_respecification_or_retirement_2026-08-21.md`.
Card store (runtime, not git-tracked): `D:/QM/strategy_farm/artifacts/cards_review/`.

## Outcome summary

| Outcome | Count |
|---|---:|
| RESPECIFY-APPROVE | 16 |
| REJECT (incl. RESPECIFY-attempt-fail) | 12 |
| Undecided | 0 |
| **Total adjudicated** | **28** |

Of the 12 rejects: 2 are hard R4 charter violations (non-respecifiable), 8 are
RESPECIFY-attempted-source-insufficient, 2 are RESPECIFY-attempted-then-conceded
(R2/R3, see the concurrent-lane note below).

## Rubric failure distribution

One card can be defective on several axes as-written; the counts below are the
TERMINAL fail reason (what kept it rejected), and the respecification tally.

| Terminal finding | Cards |
|---|---:|
| R1 (no traceable source) | 0 |
| R2 (mechanical closure) | 9 |
| R3 (governed-data) | 1 |
| R4 (ML / charter) | 2 |
| **RESPECIFY attempts** | **26** (all except the 2 pure-R4 rejects) |
| RESPECIFY succeeded → APPROVE | 16 |
| RESPECIFY failed → REJECT | 10 (8 source-insufficient + 2 conceded) |

R1 was never a reject reason: every card carries a traceable lineage tag
(`live_balke`, `research_carver`, `research_quantopian`, `forex_factory_*`,
`price_action_legend`), which R1 (informational since DL-082) accepts.
R3 is satisfied for all FX/metal/index cards — every referenced instrument
(EURUSD, GBPUSD, XAUUSD, SP500.DWX, NDX.DWX, …) is in
`framework/registry/dwx_symbol_matrix.csv` and archive-covered by the active
custom-history manifest. The single R3 reject (11931) is a mechanic-portability
failure, not a missing-symbol failure.

## Per-card decisions

### Part 2 — wave-1 reopens (one RESPECIFY attempt each)

| EA | Decision | Failed check (wave-1) | One-line result |
|---|---|---|---|
| QM5_11924 | RESPECIFY-APPROVE | R2 (RSI 14-or-20) | Resolved RSI to canonical 14; pinned closed-bar signal, 0.6% dev, 2% stop, sizing. |
| QM5_11926 | RESPECIFY-APPROVE | R2 (alt exits + no sizing) | Resolved to the single Standard 5%SL/1%TP regime; added RISK_FIXED/PERCENT sizing. |
| QM5_11927 | RESPECIFY-APPROVE | R2 (direction/timing/closed-bar) | Pinned last-closed-H1 signal, outlier-candle direction rule, next-bar-open entry, sizing. |

### Part 1 — wave 2 (25 cards, in decision-list order)

| EA | Decision | Failed check | One-line reason |
|---|---|---|---|
| QM5_11930 carver-ewm-volat | RESPECIFY-REJECT | R2 | Attempted; conceded — 28-instrument vol-targeted PORTFOLIO allocator can't be faithfully reduced to a single-symbol closed form without inventing the allocation layer. |
| QM5_11931 qp-spy-overnight-gap | RESPECIFY-REJECT | R3 | Attempted; conceded — equity cash-session overnight GAP is not reproducible on the continuous 24h SP500.DWX CFD (no cash-open discontinuity). |
| QM5_11932 ff-tms-big-e | RESPECIFY-APPROVE | R2 | Canonical TDI (RSI13/SMA2-7-34) + Heiken-Ashi confirm; exit = green crosses yellow base line; SL 60 pips. |
| QM5_11933 ff-holo-tooslow | RESPECIFY-APPROVE | R2 | Running max/min of H1 opens (00:00 reset), two-condition fade trigger, TP resolved to 15 pips. |
| QM5_11934 ff-nel-4h-macd | RESPECIFY-REJECT | R2 | Source insufficient — "Zero Line Reject" pullback/bounce state machine (window, tolerance, EMA-bounce) undefined; pinning invents it. |
| QM5_11935 ff-sonic-r | RESPECIFY-APPROVE | R2 | Dragon EMA34(H/L/C) tunnel + 89 EMA filter, break+retest state machine, 1.5R TP, 89-EMA SL. |
| QM5_11936 ff-millipede-pipeasy | REJECT | R4 | Charter: "millipede" stacks a new leg each day = pyramiding/multiple positions per magic. Non-respecifiable. |
| QM5_11937 ff-agnew-h1-break | RESPECIFY-APPROVE | R2 | Prior-H1 breakout OCO stops, London/NY window, expiry, TP resolved to 15 pips (1:1). |
| QM5_11938 ff-paulus-4h-trend | RESPECIFY-REJECT | R2 | Source insufficient — SuperTrend multiplier missing AND BB-MACD "dots" color rule undefined; both are the core signal. |
| QM5_11939 ff-j16-pin-rejection | RESPECIFY-APPROVE | R2 | 24h HHO/LLO S/R, 60%-wick/20%-body pin geometry, 50%-wick limit, 5-pip SL, 1:2 TP; TF resolved to H4. |
| QM5_11940 ff-two-stroke-chow | REJECT | R4 | Charter: opens TWO simultaneous positions per magic. Non-respecifiable. |
| QM5_11941 ff-inst-code-levels | RESPECIFY-APPROVE | R2 | Round-number grid + PDH/PDL limits, H1-EMA50 direction gate, 12/18-pip SL/TP, Asian window. |
| QM5_11942 ff-10gmt-ema50 | RESPECIFY-APPROVE | R2 | First M5 EMA50 cross after 10:00 GMT (latched), crossover-candle SL (20-pip floor), 14:00-or-1.5R exit. |
| QM5_11943 ff-wae-explosion | RESPECIFY-APPROVE | R2 | Canonical WAE up/down bars, explosion line = BB width, EMA200 filter, 10-bar swing SL. |
| QM5_11944 ff-d1-simplicity | RESPECIFY-APPROVE | R2 | Three-candle reversal; resolved the limit/stop contradiction to a stop-order breakout; 5-pip SL, 2:1 TP. |
| QM5_11945 ff-the-strat-212 | RESPECIFY-APPROVE | R2 | Rob Smith Strat scenarios as inequalities, 2-1-2 on bars 3/2/1, FTFC weekly+daily, inside-bar SL, candle-3 TP. |
| QM5_11946 ff-genesis-matrix | RESPECIFY-REJECT | R2 | Source insufficient — proprietary "Genesis Matrix" square-coloring rule not publicly closed-form. |
| QM5_11947 ff-baguba-pullback | RESPECIFY-REJECT | R2 | Source insufficient — currency-strength 0-10 normalized thresholds undefined + repainting TMA. |
| QM5_11948 ff-davit-pivots | RESPECIFY-APPROVE | R2 | Standard floor pivots, RSI(5) <20/>80, PP target, 40-pip SL floored beyond S2/R2, TF H1. |
| QM5_11949 ff-london-7am-break | RESPECIFY-APPROVE | R2 | 07:00 GMT reference-candle OCO stops, 12:00 expiry, RC-opposite SL, 2:1-or-13:30 first-touch exit. |
| QM5_11950 ff-ozfx-mechanical | RESPECIFY-APPROVE | R2/R4 | AC-zero-cross + Stoch(5,3,3) entry; "5-lot" re-expressed as one position with 20% partial closes (honors 1-pos-per-magic). |
| QM5_11951 ff-extreme-tma | RESPECIFY-REJECT | R2 | Source insufficient — TMA channel REPAINTS (non-deterministic edge) and slope-0.30 threshold has undefined units. |
| QM5_11952 ff-mad-scalper | RESPECIFY-REJECT | R2 | Source insufficient — proprietary "Shade" region and unspecified "DoubleCCI" are the core signal. |
| QM5_11953 ff-g7-strategy | RESPECIFY-REJECT | R2 | Source insufficient — Fibonacci-zone swing anchor undefined + unresolved 200SMA/BB bounce either-or. |
| QM5_11954 ff-jarroo-boss | RESPECIFY-REJECT | R2 | Source insufficient — HCR/LCS level-construction algorithm (window, granularity, "2 bodies failed") under-determined. |

## Respecification method (approved cards)

Each approved card body was edited in place: the defective passage was quoted,
replaced with an unambiguous closed-form rule traceable to the cited source
(standard indicator definitions or price-action patterns), a `Target symbols:`
line + `source_id`/`target_symbols` frontmatter were added, and a dated
`## Respecification Provenance (2026-08-21)` section records exactly what was
resolved and why. No strategy mechanics were invented: only side-parameter
ranges (SL/TP pip ranges, alternative exits, unresolved indicator periods,
multi-timeframe either-ors) were resolved to a single defensible value grounded
in the card's own stated bounds and the source's canonical spec. Cards whose
CORE signal was proprietary/undefined were NOT force-fitted — they were rejected
"RESPECIFY attempted, source insufficient".

## Verification

- 28/28 cards carry a terminal `g0_status` (16 APPROVED, 12 REJECTED); a
  programmatic frontmatter scan confirmed 0 non-terminal and 0 mismatches vs the
  intended decision list.
- All governed transitions were applied via `farmctl.py approve-card` /
  `reject-card` (exit 0, `approved:true` / `rejected:true`). Approvals passed the
  full CLI gate chain: `strategy_card_r_gate_consistency`,
  `_approval_card_contract_issues` (target_symbols frontmatter + timeframe
  literal), `_verify_card_body_coverage`, trade-frequency ≥ 2, and
  `custom_history_archive_admission` (every target symbol is archive-covered).
- Machine-readable receipt: there is NO per-card JSON receipt for
  approve/reject-card — the CLI records the verdict IN-PLACE in card frontmatter
  (`g0_status` + `g0_approval_reasoning` / `g0_rejection_reason` +
  `expected_pf`/`expected_dd_pct` + `last_updated`). The `artifacts/reviews/*.json`
  files (e.g. wave-1's `88273f13-…json`) are per-TASK router receipts, not
  per-card, and are emitted by the router on task close, not by these CLIs.
- The D: `cards_review` card files are runtime artifacts and are NOT git-tracked
  (a repo `git ls-files` grep for these ea_ids returns nothing; the
  `strategy-seeds/cards/` mirror holds a different id universe). Therefore only
  this evidence doc is committed; the card-body edits live in the runtime store.

## Concurrent-lane conflict (operational finding — needs orchestrator dedupe)

A second adjudication lane processed the identical 11930–11954 range in one
sweep at ~19:50:42–19:51:29, AFTER this wave's approvals (~19:45–19:50), and
rewrote the frontmatter of 11 already-approved cards to REJECTED. Diagnostic:
- It applied the OLD reject-only bootstrap (no RESPECIFY outcome) and reasoned
  from the ORIGINAL pre-respecification card text — e.g. it rejected 11944 citing
  "a Buy 'limit at the high of the signal candle'" (a phrase this wave had already
  removed by switching to a stop order), 11932 citing "TDI has no periods
  specified", and 11948 citing "pivot period Daily or Weekly … unresolved". Those
  defects were the exact ones this wave's respecification closed.
- This wave's respecified card BODIES were intact (the other lane touched only
  frontmatter).
- Resolution taken: for the 9 cards that are unambiguously closed-form after
  respecification (11932/33/35/37/39/41/43/44/48) this wave's authoritative
  RESPECIFY-APPROVE was re-asserted once (verified stable to 19:54). For the two
  genuinely weakest of the flipped set — 11930 (Carver portfolio allocator) and
  11931 (overnight-gap on a continuous CFD) — the concurrent lane's R2/R3
  objections are substantively correct, so they were CONCEDED to REJECTED rather
  than contested. No approve/reject flapping war was entered.
- Action for the orchestrator: dedupe the duplicate cards-review dispatch so two
  lanes do not race the same card set; the reject-only lane should not run over a
  RESPECIFY wave.
