# QM5_11903_lawler-supply-demand-zones-20-dma-h1 — Strategy Spec

**EA ID:** QM5_11903
**Slug:** `lawler-supply-demand-zones-20-dma-h1`
**Source:** `6e4b9c5a-2f78-5d36-a917-c8b3d5e4f1a2`
**Author of this spec:** Codex
**Last revised:** 2026-07-11

---

## 1. Strategy Logic

On each completed H1 bar, the EA looks for one to ten consecutive base candles
whose individual ranges are smaller than ATR(14). The next candle must expand to
at least two times the ATR measured at the end of the base and close outside the
base. An upside break creates a demand zone when SMA(20) is higher than it was
ten bars earlier; a downside break creates a supply zone when the slope is
negative.

The first closed-bar retest of a fresh zone triggers in the breakout direction
at the zone edge. The stop is five pips beyond the far edge and the primary
target is three times the initial risk. A zone expires after 240 H1 bars or is
invalidated by a close through its far edge. An open trade also exits when the
SMA slope reverses or after 480 H1 bars. Framework Friday-close, risk, kill
switch, and entry-only news controls remain in force.

The approved card also names a closer "next visible" ZigZag target without a
causal definition. This deterministic build uses the explicitly primary 3R
target and does not introduce a repainting or forward-looking target. Retests
are modeled on the first completed H1 bar that trades through the limit level;
the framework submits the entry at market on the following tick.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_dma_period` | 20 | 2–250 | H1 simple-moving-average trend period. |
| `strategy_dma_slope_bars` | 10 | 1–100 | Bars separating the two SMA values used for slope. |
| `strategy_atr_period` | 14 | 2–100 | ATR period used for base and expansion tests. |
| `strategy_erc_atr_mult` | 2.0 | 1.0–5.0 | Minimum breakout-candle range in base-end ATR units. |
| `strategy_zone_min_candles` | 1 | 1–10 | Minimum number of candles in a base. |
| `strategy_zone_max_candles` | 10 | 1–20 | Maximum number of candles in a base. |
| `strategy_zone_validity` | 240 | 1–1000 | Maximum H1 bars a fresh zone can await a retest. |
| `strategy_target_rr` | 3.0 | 0.5–10.0 | Primary take-profit reward/risk multiple. |
| `strategy_time_stop_bars` | 480 | 1–2000 | Maximum H1 holding period. |
| `strategy_sl_buffer_pips` | 5 | 0–100 | Stop buffer beyond the far side of the zone. |
| `strategy_entry_buffer_pips` | 1 | 0–50 | Retest entry offset inside the near zone edge. |
| `strategy_max_spread_points` | 0 | 0–1000 | Optional execution cap; zero disables it. |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX` — liquid major-pair anchors.
- `USDCAD.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX` — additional liquid
  major-dollar carriers for cross-regime coverage.
- `EURJPY.DWX`, `GBPJPY.DWX`, `AUDJPY.DWX` — liquid JPY crosses that broaden
  volatility and session exposure.

All ten symbols are present in `framework/registry/dwx_symbol_matrix.csv` and
use distinct registered magic slots.

**Explicitly NOT for:**

- Indices, metals, and energy CFDs — they are outside this approved FX card and
  require a separate portability review.
- Any symbol without `.DWX` history — research and pipeline artifacts retain
  the canonical suffix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 30 |
| Typical hold time | several hours to several days; hard cap 480 H1 bars |
| Expected drawdown profile | clustered losses when expansion fails to continue after a retest |
| Regime preference | directional expansion following a compact base |
| Win rate target (qualitative) | low to medium, offset by a 3R primary target |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e4b9c5a-2f78-5d36-a917-c8b3d5e4f1a2`
**Source type:** institutional research article / canonical technical-analysis method
**Pointer:** Jasper Lawler, “Price Action Trading Strategy: Supply & Demand
Zones,” FlowBank, 28 June 2021, `https://www.flowbank.com/en/research`; the
underlying market-structure concept traces to Richard Wyckoff.
**R1–R4 verdict (Q00):** all PASS; see
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_11903_lawler-supply-demand-zones-20-dma-h1.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-26 | Initial implementation from approved card | Legacy build |
| v1.1 | 2026-07-11 | Q02 infrastructure recovery | Farm claim `35726d80-e5cb-4d01-bdc2-ce08c03ad2ee`; card defaults unchanged; deterministic target/entry interpretation documented |
