# Balke Time-Range-Breakout — Walkforward Verdict (QM5_13213)

**Date:** 2026-07-14 · **Author:** Claude (Opus) · **EA:** `QM5_13213_balke-gmt3-range-breakout`
(commit `46f0e2251`, branch `agents/sonnet-balke-rangebreakout`)

## Question (OWNER, 2026-07-13)

René Balke's Time Range Breakout is profitable for him on XAUUSD and USDJPY — where does it
fail for us? Was the time window implemented wrong?

## Background

- Our earlier port `QM5_1142` used a **wrong window** (`range_start_hour_broker = 22`, raw
  broker hours, evening range) → Q04 FAIL, 0 trades. The working sibling `QM5_9936`
  (01:00–06:00 GMT+3, `Strategy_Gmt3Hour` normalization) passed Q04 with PF 1.31.
- agy video analysis (2026-07-13) established Balke's exact parameters: range **03:00–06:00
  broker time (GMT+2/+3, DST-aware)**, buy-stop at range high / sell-stop at range low after
  06:00, close all + cancel pending ~18:00; USDJPY his favorite; gold "has drawdown phases".
- 13213 = 9936's proven GMT-normalization + Balke's exact 03:00–06:00/18:00 parameters.

## Method

Ad-hoc walkforward gate (NOT a pipeline verdict), parked terminal T9, MT5 Model 4 real-tick,
H1, RISK_FIXED sizing, DWX data ($0 commission/swap → **all numbers GROSS**).
Split: DEV 2017.01.01–2021.09.30 / OOS 2021.10.01–2025.12.31.
Metrics from per-trade q08 streams (TRADE_CLOSED events, equity-curve MaxDD).
Runner: `D:\QM\reports\balke_walkforward\run_wf.py` · results:
`D:\QM\reports\balke_walkforward\result.json` · round-1 log: `bwf_task_round1.out`.

Round-1 XAU nulls were harness defects (30-min timeout too short for XAU real-tick; retry
loop had zero time budget — q08 stream flushes only on clean OnDeinit). Fixed (100-min
timeout, per-attempt t0) and re-run; T9 tester log confirms clean trading behavior
(06:00 stop placement, 18:00 close, trailing).

## Results (gross, RISK_FIXED)

| Window | Trades | Net | PF | MaxDD |
|---|---|---|---|---|
| USDJPY DEV 2017-01→2021-09 | 791 | +$74,503 | **1.24** | −$17,149 |
| USDJPY OOS 2021-10→2025-12 | 795 | +$68,235 | **1.20** | −$19,853 |
| XAU DEV 2017-01→2021-09 | 924 | +$52,177 | 1.12 | −$25,307 |
| XAU OOS 2021-10→2025-12 | 970 | +$13,342 | **1.03** | −$40,645 |

## Findings

1. **The window WAS the failure.** With correct GMT-normalized 03:00–06:00, the strategy is
   OOS-profitable on USDJPY across 795 trades with almost no DEV→OOS degradation
   (1.24 → 1.20). 1142's Q04 FAIL was purely the mis-implemented 22:00 raw-broker window.
2. **USDJPY = WIN (gross AND costed).** Stable walkforward signature, ~187 trades/yr.
   **Costed with venue truth (OWNER directive 2026-07-14: no harsh worst-case
   assumptions):** recomputed from the actual OOS stream (795 trades, avg 4.39 lots,
   avg notional $397k) — embedded DWX commission stripped, venue model re-applied:

   | Cost model | OOS Net | PF | MaxDD | comm/trade |
   |---|---|---|---|---|
   | Gross (no cost) | +$76,964 | 1.223 | −$19,098 | $0 |
   | Registry max(0.5bps, $5/lot) | +$59,496 | **1.168** | −$20,607 | $21.97 |
   | DXZ truth ($5/lot RT) | +$59,511 | 1.168 | −$20,607 | $21.95 |
   | FTMO truth ($3/lot RT) | +$66,492 | **1.190** | −$20,003 | $13.17 |
   | ~~old blanket $45/trade~~ | ~~+$41,189~~ | ~~1.113~~ | — | (wrong: other EAs' lot profile) |

   The earlier "~$45/trade → PF ~1.09" caveat was a blanket average measured on OTHER
   FX EAs with larger lots — 13213's true realized commission is ~$22/trade (DXZ) /
   ~$13/trade (FTMO). **Swap = exactly $0, not an assumption:** max hold 12.0h, zero
   trades >24h (the 18:00 close guarantees no overnight positions).
3. **XAU = NO WIN.** OOS PF 1.03 gross ≈ breakeven before costs, MaxDD −$40.6k vs net
   +$13.3k. Reproduces Balke's own caveat ("gold has drawdown phases") and our independent
   master-EA finding that XAU range-breakout styles whipsaw.
4. **Video-derived parameters reproduce the author's qualitative claims** (USDJPY strong,
   gold weak) — the agy transcript-analysis lane delivered actionable, correct parameters.

## Verdict & recommendation

- **USDJPY:** enqueue 13213 into the deterministic pipeline (Q02+, full history, costed
  gates downstream). Card should carry `target_symbols: USDJPY.DWX` only.
- **XAU:** documented negative; do not pursue (consistent with Balke's own experience).
- **9936 (01:00–06:00 GMT+3, Q04 PF 1.31)** is in the INFRA_FAIL recovery pool — when its
  Q05 re-runs, compare head-to-head with 13213; the wider window may dominate Balke's exact
  window on USDJPY. Keep both until the pipeline decides.
