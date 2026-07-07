# QM5_9250_mql5-crt-amd — Strategy Spec

**EA ID:** QM5_9250
**Slug:** `mql5-crt-amd`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA trades Candle Range Theory / AMD reversals on M15. The previous completed H1 candle defines the accumulation range. If that H1 candle closed up, the EA looks for the following M15 bars to sweep below the H1 low by at least 10% of the H1 range and then close back above the H1 low. That confirmed sweep opens a long trade. If the H1 candle closed down, the mirror setup sweeps above the H1 high and closes back below it to open a short trade.

The range must be between 0.5 and 2.5 times ATR(14) on H1. Stops use the manipulation extreme plus a 0.25 ATR(14) M15 buffer. Take profit is fixed at 2.0R. Positions also close on an opposite CRT AMD signal or after 48 M15 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_range_tf` | `PERIOD_H1` | H1-H4 | Higher-timeframe candle used as the accumulation range. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for range sizing and stop buffer. |
| `strategy_min_range_atr_mult` | 0.50 | 0.10-5.00 | Minimum H1 range size relative to H1 ATR. |
| `strategy_max_range_atr_mult` | 2.50 | 0.50-10.00 | Maximum H1 range size relative to H1 ATR. |
| `strategy_min_manip_depth_pct` | 10.0 | 1.0-100.0 | Required sweep depth as a percent of the H1 range. |
| `strategy_confirm_bars` | 1 | 1-4 | Closed M15 bars required back inside the range after manipulation. |
| `strategy_stop_atr_buffer` | 0.25 | 0.00-2.00 | ATR buffer beyond the sweep extreme for the structural stop. |
| `strategy_take_profit_r` | 2.0 | 0.25-5.00 | Fixed take-profit distance in R multiples. |
| `strategy_max_hold_bars` | 48 | 1-192 | M15 bars before the rule-based time stop. |
| `strategy_scan_bars` | 16 | 4-96 | Bounded M15 lookback for post-range manipulation/confirmation. |
| `strategy_max_spread_stop_pct` | 12.0 | 0.0-50.0 | Entry spread cap as a percent of stop distance; 0 disables the cap. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid FX major in the approved DWX matrix and one of the card targets.
- `GBPUSD.DWX` — liquid FX major in the approved DWX matrix and one of the card targets.

**Explicitly NOT for:**
- `GER40.DWX` — listed on the card, but intentionally deferred in this build because the current mission prioritizes forex diversity over another index sleeve.
- non-`.DWX` symbols — the farm gates and magic registry are defined for DWX instruments only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | Previous completed H1 range; H1 ATR(14) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 framework |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | About 70 |
| Typical hold time | Intraday to two trading days; hard cap is 48 M15 bars |
| Expected drawdown profile | Stop distance follows the sweep extreme plus ATR buffer, so drawdown expands in volatile manipulation regimes |
| Regime preference | Liquidity-sweep mean reversion after a defined accumulation range |
| Win rate target (qualitative) | Medium, with asymmetric 2R winners |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** MQL5 article
**Pointer:** Allan Munene Mutiiria, "Automating Trading Strategies in MQL5 (Part 41): Candle Range Theory (CRT) - Accumulation, Manipulation, Distribution (AMD)", MQL5 Articles, 2025-11-21, https://www.mql5.com/en/articles/20323
**R1-R4 verdict (Q00):** all PASS; see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9250_mql5-crt-amd.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3%-0.5% |

ENV-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-07 | Initial build from approved card | Commit pending |
