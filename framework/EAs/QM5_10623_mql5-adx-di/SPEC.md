# QM5_10623_mql5-adx-di - Strategy Spec

**EA ID:** QM5_10623
**Slug:** `mql5-adx-di`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

This EA evaluates completed H1 bars only. It opens a long trade when ADX +DI(28) crosses upward through level 5 from the prior closed bar to the latest closed bar. It opens a short trade when ADX -DI(28) crosses downward through level 5 from the prior closed bar to the latest closed bar. Each trade uses a fixed 500-point stop loss and 500-point take profit; framework kill-switch, news pause, and Friday close remain active.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_adx_period` | 28 | integer > 0 | ADX period used for +DI and -DI reads. |
| `strategy_plus_di_level` | 5.0 | value > 0 | Long threshold for the +DI upward cross. |
| `strategy_minus_di_level` | 5.0 | value > 0 | Short threshold for the -DI downward cross. |
| `strategy_stop_loss_points` | 500 | integer > 0 | Fixed stop distance in broker points. |
| `strategy_take_profit_points` | 500 | integer > 0 | Fixed target distance in broker points. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX symbol with ADX derived from OHLC.
- `GBPUSD.DWX` - card-listed major FX symbol with ADX derived from OHLC.
- `USDJPY.DWX` - card-listed major FX symbol with ADX derived from OHLC.
- `XAUUSD.DWX` - card-listed metal symbol with ADX derived from OHLC.

**Explicitly NOT for:**
- Symbols outside the four card-listed `.DWX` markets - not part of this approved baseline build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Intraday to multi-day, bounded by fixed SL/TP and Friday close. |
| Expected drawdown profile | Fixed-risk $1,000 per backtest trade with symmetric fixed stop and target. |
| Regime preference | Directional-movement threshold expansion. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/197`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10623_mql5-adx-di.md`

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
| v1 | 2026-05-31 | Initial build from card | 8b551a53-72d2-4416-a5c1-016f99256458 |
