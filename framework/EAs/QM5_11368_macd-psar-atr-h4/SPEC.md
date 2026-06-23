# QM5_11368_macd-psar-atr-h4 — Strategy Spec

**EA ID:** QM5_11368
**Slug:** `macd-psar-atr-h4`
**Source:** `59508e92-3f5c-50ea-80e6-f96fec946283` (see `strategy-seeds/sources/59508e92-3f5c-50ea-80e6-f96fec946283/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

H4 trend-following system combining MACD(12,26,9), Parabolic SAR(0.02/0.2) and
ATR(14). Long when the MACD MAIN line crosses above zero on the just-closed H4
bar and the Parabolic SAR is below that bar's close. Short is the mirror: MACD
crosses below zero and SAR is above the close. The stop is the Parabolic SAR
value at entry, capped to 50 pips for P2, then trailed toward the current SAR
and never moved backward. Take-profit is a single P2 target at the larger of
2×ATR from entry or 2× the stop distance. All signal reads are on the closed
bar (shift 1).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 12 | 5-20 | MACD fast EMA period |
| `strategy_macd_slow` | 26 | 20-40 | MACD slow EMA period |
| `strategy_macd_signal` | 9 | 5-12 | MACD signal SMA period |
| `strategy_sar_step` | 0.02 | 0.01-0.05 | Parabolic SAR acceleration step |
| `strategy_sar_max` | 0.2 | 0.1-0.3 | Parabolic SAR max acceleration factor |
| `strategy_atr_period` | 14 | 10-20 | ATR period for target distance |
| `strategy_tp_atr_mult` | 2.0 | 1.5-3.0 | Take-profit distance = mult × ATR |
| `strategy_min_rr` | 2.0 | 1.0-3.0 | Minimum reward:risk target multiple |
| `strategy_stop_cap_pips` | 50 | 20-100 | Maximum stop distance for P2 |
| `strategy_spread_cap_pips` | 20 | 5-30 | Skip if spread is above this cap |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary pair the source strategy is demonstrated on; deep, liquid H4 trend behaviour.
- `AUDUSD.DWX` — second demonstrated pair; commodity-FX trends suit PSAR/MACD trend-follow.
- `GBPUSD.DWX` — liquid major with comparable H4 trend structure; named in card filters.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — card scopes this to the three demonstrated FX majors.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` (card's optional D1/W1 S/R check not mechanised) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~50` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `trend-follower: many small losses, fewer larger trend wins` |
| Regime preference | `trend` |
| Expected trade frequency | `roughly weekly per symbol` |
| Win rate target (qualitative) | `low/medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `59508e92-3f5c-50ea-80e6-f96fec946283`
**Source type:** `paper` (anonymous forex strategy PDF)
**Pointer:** local PDF `640322690-MACD-Trender-Forex-Trading-Strategy.pdf` (see card `source_citation`)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11368_macd-psar-atr-h4.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-23 | Initial build from card | a9c9c2af-6fde-475b-b65b-702598fbf880 |
