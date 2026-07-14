# QM5_9250_mql5-crt-amd - Strategy Spec

**EA ID:** QM5_9250
**Slug:** `mql5-crt-amd`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Codex; revised by Claude
**Last revised:** 2026-07-14

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
- `EURUSD.DWX` - liquid FX major in the approved DWX matrix and one of the card targets.
- `GBPUSD.DWX` - liquid FX major in the approved DWX matrix and one of the card targets.
- `GDAXI.DWX` - port of the card's `GER40.DWX` target; `GER40.DWX` is not a valid symbol in `dwx_symbol_matrix.csv`, `GDAXI.DWX` is the canonical DAX-40 DWX Custom Symbol (per CLAUDE.md DWX symbol-port convention). Registered 2026-07-14 to satisfy the P2 Saturation Rule (the v1 2026-07-07 build had deferred it; that deferral was not a card-sanctioned exception, so the card's full 3-symbol basket is now registered).

**Explicitly NOT for:**
- non-`.DWX` symbols - the farm gates and magic registry are defined for DWX instruments only.

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
| v2 | 2026-07-14 | P2 Saturation Rule fix: registered `GDAXI.DWX` (slot 2, ported from card's `GER40.DWX`) which v1 had deferred without a card-sanctioned exception; also moved the opposite-signal exit check out of the per-tick `Strategy_ExitSignal` path (it previously called an ungated multi-bar `CopyRates` scan every tick while a position was open) into the once-per-closed-bar `Strategy_EntrySignal` scan, closing the prior position there when a fresh opposite setup confirms | build task dc6908f8-c9bb-4f4e-95dd-381e58486b8b |
