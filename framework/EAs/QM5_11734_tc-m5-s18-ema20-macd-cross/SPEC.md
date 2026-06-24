# QM5_11734_tc-m5-s18-ema20-macd-cross - Strategy Spec

**EA ID:** QM5_11734
**Slug:** `tc-m5-s18-ema20-macd-cross`
**Source:** `40a4454c-64ff-5015-8538-9f7b32abc0e9` (see `sources/tc-m5-20-forex-strategies`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades an M5 EMA(20) price-cross setup confirmed by MACD(12,26,9). A long setup requires price to move from below EMA(20) to above EMA(20), a negative MACD background, and a bullish MACD main-line cross above the signal line within the last five closed bars. A short setup mirrors that logic. Entry is a stop order 10 pips beyond EMA(20); the conservative stop is 20 pips on the opposite side of EMA(20), half the position closes at 2R, and the remainder trails against EMA(20) by 15 pips or exits on an opposite EMA(20) cross.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 20 | 2-200 | EMA period used for the price-cross trigger and trailing stop anchor. |
| `strategy_macd_fast` | 12 | 2-100 | Fast EMA period for MACD. |
| `strategy_macd_slow` | 26 | 3-200 | Slow EMA period for MACD. |
| `strategy_macd_signal` | 9 | 2-100 | Signal EMA period for MACD. |
| `strategy_macd_cross_lookback` | 5 | 1-20 | Closed-bar window in which the MACD cross must have occurred. |
| `strategy_entry_buffer_pips` | 10 | 1-100 | Stop-entry offset from EMA(20). |
| `strategy_sl_from_ema_pips` | 20 | 1-200 | Conservative stop distance from EMA(20). |
| `strategy_trail_from_ema_pips` | 15 | 1-200 | Trailing stop distance from EMA(20) after the partial exit condition. |
| `strategy_partial_rr` | 2.0 | 0.5-10.0 | Profit multiple of initial risk that triggers the partial close. |
| `strategy_partial_fraction` | 0.50 | 0.10-0.90 | Fraction of the open position to close at the partial-exit trigger. |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target; major FX pair with M5 DWX data.
- `GBPUSD.DWX` - card target; major FX pair with M5 DWX data.
- `USDJPY.DWX` - card target; major FX pair with M5 DWX data.
- `USDCHF.DWX` - card target; major FX pair with M5 DWX data.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the source strategy is a 5-minute forex setup and the card only names FX majors.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `150` |
| Expected trade frequency | M5 cadence; frequent but gated by price/EMA and MACD cross agreement. |
| Typical hold time | Intraday to multi-session, depending on EMA trailing-stop progression. |
| Expected drawdown profile | Trend-following drawdowns during choppy EMA whipsaw regimes. |
| Regime preference | Trend-following momentum after EMA(20) transition. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `40a4454c-64ff-5015-8538-9f7b32abc0e9`
**Source type:** book/PDF strategy collection
**Pointer:** Thomas Carter, `20 Forex Trading Strategies (5 Minute Time Frame)`, Strategy #18, 2013; local PDF archive.
**R1-R4 verdict (Q00):** frontmatter marks R1-R4 PASS and `g0_status: APPROVED`; see `artifacts/cards_approved/QM5_11734_tc-m5-s18-ema20-macd-cross.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-25 | Initial build from card | 6036da35-556f-4991-a1fb-2d352bbb921d |
