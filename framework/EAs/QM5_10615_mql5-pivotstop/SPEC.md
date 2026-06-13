# QM5_10615_mql5-pivotstop - Strategy Spec

**EA ID:** QM5_10615
**Slug:** `mql5-pivotstop`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA computes the daily pivot, three resistance levels, and three support levels from the previous completed D1 bar. On each completed intraday bar below D1, it buys when the last closed bar crosses upward through the pivot and sells when it crosses downward through the pivot. Stop loss and take profit are placed at the configured same-side and opposite-side pivot levels, with the source's wider fallback levels used when broker stop distance makes the primary levels unusable. If pivot levels are unusable, the stop falls back to 2.0 times ATR(14).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_target_level` | 3 | 1-3 | Selects S/R level pair for the primary stop and target. |
| `strategy_atr_period` | 14 | 2-200 | ATR lookback for the catastrophic stop fallback. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | ATR multiplier for the fallback stop distance. |
| `strategy_intraday_close_enabled` | false | true/false | Enables source `isTradeDay` behaviour to close at 23:00 broker time. |
| `strategy_breakeven_enabled` | false | true/false | Enables source `ModSL` behaviour after first S/R level is reached. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 names FX majors as portable daily OHLC pivot targets.
- `GBPUSD.DWX` - Card R3 names this as a target FX major.
- `USDJPY.DWX` - Card R3 names this as a target FX major.

**Explicitly NOT for:**
- `SPX500.DWX` - Not present in the DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | Previous completed `D1` bar for daily pivot ladder |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday to multi-day, until pivot S/R SL/TP or optional 23:00 close |
| Expected drawdown profile | Fixed-risk directional pivot crosses with one open position per symbol/magic |
| Regime preference | Daily pivot breakout/continuation from intraday pivot touch |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase expert
**Pointer:** `https://www.mql5.com/en/code/1053` and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10615_mql5-pivotstop.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10615_mql5-pivotstop.md`

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
| v1 | 2026-06-13 | Initial build from card | 14773a32-49a0-4f6f-8de5-6dd1bd1e0462 |
