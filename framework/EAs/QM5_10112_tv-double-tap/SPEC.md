# QM5_10112_tv-double-tap - Strategy Spec

**EA ID:** QM5_10112
**Slug:** `tv-double-tap`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA scans confirmed closed-bar swing pivots on H1 using a fixed five-bar pivot lookback. A long setup forms when two swing lows are within 0.5 x ATR(14), the second low does not materially break the first, and the latest closed bar breaks above the intervening swing-high neckline. A short setup mirrors this with two swing highs and a neckline break below the intervening swing low. Each trade uses a fixed structure stop beyond the pattern extreme by 0.25 x ATR(14) and a take-profit at the equal-leg projection from the neckline.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_pivot_lookback_bars` | 5 | 2-20 | Closed bars on each side required to confirm a swing pivot. |
| `strategy_atr_period` | 14 | 1-100 | ATR period used for pivot tolerance and stop buffer. |
| `strategy_pivot_tolerance_atr` | 0.50 | 0.10-2.00 | Maximum distance between the two pattern extremes, in ATR units. |
| `strategy_stop_buffer_atr` | 0.25 | 0.05-2.00 | Stop distance beyond the double-top or double-bottom extreme, in ATR units. |
| `strategy_scan_bars` | 220 | 40-1000 | Closed bars scanned for confirmed zig-zag pivots. |
| `strategy_max_spread_points` | 0 | 0-100000 | Optional spread ceiling in points; 0 disables this strategy-specific filter. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid major FX pair with stable H1 OHLC history.
- `GBPUSD.DWX` - card-listed liquid major FX pair suited to swing-pattern breakouts.
- `XAUUSD.DWX` - card-listed gold CFD with enough volatility for ATR-buffered structural patterns.
- `NDX.DWX` - card-listed index CFD with liquid H1 trend and reversal structure.

**Explicitly NOT for:**
- `SPY.DWX` - unavailable in the DWX matrix; the card does not request an S&P 500 port.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `24` |
| Typical hold time | hours to several days |
| Expected drawdown profile | Pattern-breakout losses cluster during choppy failed-neckline regimes. |
| Regime preference | breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** Bjorgum, "Bjorgum Double Tap", TradingView, 2022-06-13
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10112_tv-double-tap.md`

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
| v1 | 2026-06-12 | Initial build from card | 02066b37-a606-4d74-8168-c6add67dd009 |
