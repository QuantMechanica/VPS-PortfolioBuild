---
source_id: QM-RESEARCH-2026-0010
title: US pre-open range breakout on XAUUSD (H-V2, 08:30 America/New_York gold-specific session mechanism) — revision 2
source_type: internal_research
source_author: Claude
source_model: claude-fable-5-1
created: 2026-09-21
originating_task_id: 31012467-dde7-4b74-995c-def2241b28c0
status: draft
parent_source_ids: []
source_artifact: QM-RESEARCH://2026-0010
---

# US pre-open range breakout on XAUUSD (H-V2, 08:30 America/New_York gold-specific session mechanism) — revision 2

## Research provenance

Revision 1 was authored by Claude (claude-sonnet-5) under task `31012467-dde7-4b74-995c-def2241b28c0`
(routed by Fable) against the frozen 2026-09-20 Velocity evidence cohort. Revision 2 (2026-09-21, Fable /
claude-fable-5-1, same task lineage) answers the cross-vendor critique `1614737c` verbatim in
`docs/ops/evidence/2026-09-20_velocity_book/hv1_hv3_critique_1614737c.md` and replaces every prior by a
measurement. No ML/statistical search instrument was used. Figures come from two deterministic computed
outputs sealed next to this file:

- `baseline_extract.json` — frozen Q02-screen / README figures (10423, 11690, 10700, 13213), produced by
  `tools/strategy_farm/session_tools/velocity_hv1_hv3_baseline_extract_20260921.py`;
- `prescreen_extract.json` — the closed-bar M1 prescreen of THIS mechanism on the factory's `.DWX` custom
  history (XAUUSD.DWX, 2018-07-02..2025-12-31, 0 factory hours) by
  `tools/strategy_farm/session_tools/velocity_hv_prescreen_0921.py` over
  `tools/strategy_farm/session_tools/hcc_m1_reader_0921.py` (reader validated bar-for-bar against the
  terminal's own M1 JSONL export on EURUSD/GBPUSD: 194,574 of 194,575 rows identical), including a
  spread sensitivity from the MEASURED FTMO-venue XAUUSD M1 spread harvest
  (`D:/QM/reports/ftmo_spread_calibration/XAUUSD_FTMO_M1.jsonl`, 100,000 rows, 2026-04-28..2026-08-07).

## Prescreen outcome (read this first)

**Indicative closed-bar simulation, commission-only, `.DWX` spread = 0; Q02 would have to confirm — but the
hypothesis is FALSIFIED by its own criteria on the selection period, and the measured FTMO spread alone
exceeds any plausible expectancy, so no Q02 canary is requested.**

| period (bd) | arm | trades | trades/bd | E[R] net (commission only) | PF | worst-year DD (R) | R/bd |
|---|---|---|---|---|---|---|---|
| SEL 2018-07..2022-12 (1175) | A15 | 682 | 0.58 | −0.050 | 0.91 | 27.8 | −0.029 |
| SEL | A20 | 682 | 0.58 | −0.046 | 0.92 | 29.1 | −0.027 |
| VAL 2023..2025 (782) | A15 | 447 | 0.57 | +0.038 | 1.07 | 19.7 | +0.022 |
| VAL | A20 | 447 | 0.57 | +0.030 | 1.05 | 22.9 | +0.017 |

Per-year net R (A15): 2018 +3.6, 2019 −21.5, 2020 −18.0, 2021 +6.6, 2022 −5.1, 2023 +9.3, 2024 −10.2,
2025 +18.0. Over the full span A15 nets −0.015R/trade before spread.

**Spread kills what commission leaves.** The reference range is small (median W = 5.05 USD in SEL,
6.53 USD in VAL); the measured FTMO XAUUSD spread (median 44 points = 0.44 USD, p90 51) is therefore
**0.087R per trade at the selection median width and 0.067R at the validation median width** — on top of a
commission of median 0.018R (p90 0.028R; 0.005 % of notional round trip, `live_commission.json`
commodity class). Spread-adjusted E[R] is ≈ −0.10R (SEL) and ≈ −0.03R (VAL) — negative in both periods.

**Disposition recommended to Fable: RETIRE (no card, no build, no factory rows)** unless the round-2
critic finds a defect in the prescreen simulator that flips the selection-period sign AND the spread
arithmetic. The reusable deliverable is the measurement harness plus the FTMO-spread sensitivity method.

## Structural cause (unchanged thesis, restated)

Gold's volatility clusters at the 08:30 America/New_York macro-release time; two always-on H1 gold
configurations in the frozen screen (10423: 0.82 trades/bd, +0.086R; 11690: 1.84 trades/bd, +0.028R)
carry real edge but failed Q05 on drawdown (41 % / 59 %). H-V2 asked whether gating the same underlying
edge to one pre-open-range breakout per day, flat before the close, keeps the edge and removes the
drawdown. The prescreen answers: the gated single-window breakout does not carry the edge (E[R] ≈ 0 before
spread), so the drawdown question is moot.

## Mechanical spec — revision 2 (frozen, buildable from this section alone)

- **Symbol:** XAUUSD (one magic slot). **Timeframes:** M15 signal, H1 for ATR(14).
- **Anchor mapping (deterministic, DST-aware):** economic anchor = **08:30 America/New_York** (the US macro
  release time; the revision-1 "13:30 UTC" conflated it with a DST-varying cash open and is withdrawn).
  Broker-time anchor = `toServer(08:30 America/New_York) = New York local + 7 h` (Darwinex NY-close server
  clock). Flat time = 16:00 America/New_York mapped identically. Because both anchor and server clock are
  defined in New York time, the offset is constant (+7 h) all year and the EU/US DST divergence windows do
  not affect this hypothesis at all; the FTMO venue's own server clock (Prague-based) would need the same
  `QM_SessionClock` helper as H-V1.
- **Reference range:** the four M15 bars starting at anchor − 60, −45, −30, −15 min (07:30-08:30 NY, all
  CLOSED at the anchor); `RH`/`RL`/`W` as in H-V1; ≥ 3 of 4 bars required.
- **Thin-range floor / wide-range cap (named, frozen from the selection period):** trade only if
  `0.85 × ATR ≤ W ≤ 2.19 × ATR`, ATR = Wilder ATR(14) on H1 bars closed at or before the anchor (p10 / p90
  of the 2018-07..2022-12 W/ATR distribution, applied unchanged to 2023-25). Measured W p10/p50/p90 =
  2.31 / 5.05 / 9.48 USD (SEL), 3.35 / 6.53 / 14.44 USD (VAL).
- **Entry window:** the four M15 bars starting in [anchor, anchor + 60 min) (08:30-09:30 NY). Closed-bar
  (shift-1) contract as in H-V1. **Signal:** the first bar in the window that CLOSES beyond RH (long) or
  below RL (short); a wick-only excursion does not decide and scanning continues (no failure variant in
  H-V2 — kept single-trigger to isolate the session-gating question).
- **Orders:** market entry at the open of the bar after the signal bar; stop distance `W`; target arms
  **A15 = 1.5 × W** and **A20 = 2.0 × W** (frozen); same-bar ambiguity → stop; hard time-stop flat at
  16:00 America/New_York (0 % overnight). One trade per day.
- **Risk:** RISK_FIXED 1000 in backtests, RISK_PERCENT live; framework news blackout applies (the 08:30 NY
  releases fall INSIDE the entry window — the blackout would remove a large share of the fires; not modelled
  in the prescreen, which is therefore an upper bound on density); no martingale / grid / averaging; no ML.
- **DD kill bar (quantified):** the worst simulated calendar-year drawdown is 27.8R (A15) / 29.1R (A20)
  at RISK_FIXED 1000, i.e. 28-29 % of a 100k account at 1 %/trade — the same failure class as 10423 (41 %).
  Rule: retire at Q05 if the max drawdown exceeds 20R (20 % at 1 %/trade), the level below which a
  0.25 %/trade FTMO sizing keeps the 10 % max-loss headroom.

## Density and cost (measured)

- Trading days 2018-07-02..2025-12-31: 1,932. Day states: 1,129 trades (all breakout), 373 no-signal,
  271 floor-excluded, 158 cap-excluded, 1 no-range. Density 0.57-0.58 trades/bd (revision-1 prior 0.5-0.7
  was right); median hold 65 min (A15).
- Commission per trade at RISK_FIXED 1000: median 0.018R, p90 0.028R (median entry price 1,844.52,
  median lots ≈ 2.0). Spread (measured, FTMO venue, 2026 harvest vs 2018-25 ranges — stated, not assumed):
  0.44 USD round trip = 0.087R / 0.067R at the SEL / VAL median width.

## Falsification criteria (as applied)

1. Density < 0.3 trades/bd → not met (0.57-0.58).
2. Net E[R] < +0.10R/trade after costs on the selection period → **met** (−0.050 / −0.046 before spread).
3. PF < 1.05 on the selection period → **met** (0.91 / 0.92).
4. Max drawdown reproduces the 10423/11690 failure class → **met** (27.8-29.1R worst year > 20R kill bar).
5. Holdout VAL ≥ 70 % of SEL R/bd → not evaluable (SEL negative).
6. Joint tail vs 10700 (|r| > 0.30 or lower-decile co-occurrence > 2×) → not evaluated (moot); daily P/L
   is in the prescreen output if ever needed.

Criteria 2-4 retire the hypothesis at the prescreen stage.

## Revision 2 (2026-09-21) — changes vs critique 1614737c

| critic point | resolution |
|---|---|
| fixed 13:30 UTC conflates a DST-varying US cash open with 08:30 ET macro time | one America/New_York economic anchor (08:30 NY), mapped deterministically to server time (+7 h, constant) |
| target 1.5x-2.0x, min range, shift-1 contract unresolved | frozen arms A15 / A20; floor / cap 0.85-2.19 × ATR(14,H1) named from SEL; closed-bar contract stated |
| density 0.5-0.7 and +0.10-0.15R unsupported extrapolations above 10423 +0.086R / 11690 +0.028R | measured: 0.58/bd and −0.050R (SEL) / +0.038R (VAL) before spread — below both comparators |
| news blackout overlaps the claimed driver | acknowledged: the 08:30 NY releases sit inside the entry window; prescreen density is an upper bound |
| cost_R not computable despite governed 0.005 % notional | computed per trade (median 0.018R) plus the measured FTMO spread (0.087R / 0.067R) |
| no min stop exists | stop = W with the named floor 0.85 × ATR(14,H1) (2.31 USD p10) |
| quantify the DD kill bar | 20R at RISK_FIXED 1000; worst simulated year 27.8R breaches it |
| fast fire-count / cost floors before Q02 | done — this prescreen; Q02 not requested |
| keep the 10700 tail test | retained as a requirement for any future revision |
| provenance: manifest hashes ≠ files | resealed; verify clean except `LEDGER_STATUS_BAD:draft` |

## Distinct from 13213 / 10706 / 10700 / 41475 / 41476 / 41477 / 10423 / 11690

Unchanged from revision 1: session-flat single-window redesign of the gold edge that 10423/11690 carry
always-on; different asset from 13213 / 10706 / 41477; 10700 (demo roster, 58 % overnight, 19.7 h hold)
is the tail-test comparator; the 41475/41476 index trio's mistimed cash-open anchor does not apply to a
continuous OTC instrument.

## Source manifest

```qm-source-manifest
# Auto-generated by research_source.seal; do not hand-edit.
research.json:          26ad7797f1cb05a58a3c62d2126a37d4f11490485a83a3a6bd84f558e9a154f4
lineage.json:           a70ce22cc3586b324e6666a88a4bae1bd6f771528212acd27fd5b8c05fca328a
critic_receipt.json:    529e8710554d85fac62d435853a1c03f01bb3170f7efbc283a06b49d698cec14
baseline_extract.json:  c43a6cee75d54f5f4a02b7b30e369874e5d43dc44d105bb96970b6255cb213a0
prescreen_extract.json: 2bf2642e666dd43542bc5e5ff65edeffb457578c71c23bb5a7118c58f55c6121
```
