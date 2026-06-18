# QM5_10908_carter-ema-stack-rsi - Strategy Spec

**EA ID:** QM5_10908
**Slug:** carter-ema-stack-rsi
**Source:** 6facee24-8a58-5bbf-88e9-38d44291db50 (see approved card source reference)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades EURUSD on H1 using Thomas Carter's multi-EMA stack with RSI confirmation. It enters long when EMA(13) and EMA(21) are above EMA(80), EMA(3) crosses above EMA(5), the EMA(3/5) pair is above or recently crossed above the EMA(13/21) pair, and RSI(21) is above 50. It enters short on the mirrored bearish conditions. Positions use a fixed 25-pip stop and exit when EMA(3) crosses back through EMA(5), RSI(21) crosses back through 50, or the trade has been open for 72 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast` | 3 | >0 | Fast EMA in the trigger cross. |
| `strategy_ema_signal` | 5 | >0 | Slow EMA in the trigger cross. |
| `strategy_ema_mid_a` | 13 | >0 | First mid-stack EMA. |
| `strategy_ema_mid_b` | 21 | >0 | Second mid-stack EMA. |
| `strategy_ema_trend` | 80 | >0 | Slow EMA trend-regime filter. |
| `strategy_rsi_period` | 21 | >0 | RSI period for entry and exit gating. |
| `strategy_rsi_level` | 50.0 | 0-100 | RSI midpoint threshold. |
| `strategy_align_lookback` | 3 | >=0 | Closed bars allowed for recent fast-pair alignment. |
| `strategy_sl_pips` | 25 | >0 | Fixed stop loss in pips. |
| `strategy_hold_bars` | 72 | >0 | Fallback time exit in base-timeframe bars. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source symbol EURUSD is present in the DWX matrix and matches the Carter source market.

**Explicitly NOT for:**
- Non-EURUSD symbols - the approved card only passes R3 for source EURUSD.DWX and does not authorize a portable basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | Up to 72 H1 bars |
| Expected drawdown profile | Trend-following pullbacks can cluster losses in sideways EURUSD regimes. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6facee24-8a58-5bbf-88e9-38d44291db50
**Source type:** book
**Pointer:** `G:/My Drive/QuantMechanica/Ebook/PDF resources/20 Forex Trading Strategies - Thomas Carter.pdf`, Thomas Carter, *20 Forex Trading Strategies (1 Hour Time Frame)*, 2014, Strategy #7, pages 16-17.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10908_carter-ema-stack-rsi.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | bfe33a77-6d00-4539-9ee1-cb7ca14a61f5 |
