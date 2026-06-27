# QM5_12620_comm-reversal-4wk-xngusd - Strategy Spec

**EA ID:** QM5_12620
**Slug:** `comm-reversal-4wk-xngusd`
**Source:** `05abad87-420d-5a51-8a9b-3c35ad795385` (see `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-27

---

## 1. Strategy Logic

This EA trades a weekly D1 overreaction reversal on `XNGUSD.DWX`. On the first
D1 bar of the trading week, it measures the prior closed D1 close against the
close 20 D1 bars earlier. If natural gas has fallen at least 6 percent, it buys.
If natural gas has risen at least 6 percent, it sells. Positions exit after 28
calendar days or via a fixed ATR stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_days` | 20 | 15-30 | D1 bars used for the short-term overreaction return |
| `strategy_atr_period` | 14 | 10-20 | ATR period for the hard stop |
| `strategy_min_abs_return_pct` | 6.0 | 4.0-10.0 | Minimum absolute lookback return needed for a reversal setup |
| `strategy_atr_sl_mult` | 2.0 | 1.5-3.0 | Hard stop distance in ATR units |
| `strategy_max_hold_days` | 28 | 14-28 | Calendar-day time stop |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

---

## 3. Symbol Universe

**Designed for:**

- `XNGUSD.DWX` - natural gas CFD available in the DWX symbol matrix; this is the intended energy reversal sleeve.

**Explicitly NOT for:**

- `XAUUSD.DWX` and `XAGUSD.DWX` - excluded to avoid adding another metal sleeve.
- `XTIUSD.DWX` - excluded because the WTI reversal sibling is already `QM5_12594`.
- Equity indices and FX pairs - outside this commodity-reversal card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 20 |
| Typical hold time | 1-28 calendar days |
| Expected drawdown profile | Medium-high; fades volatile XNG extremes with fixed ATR loss control |
| Regime preference | Short-term natural-gas mean reversion after large 4-week moves |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `05abad87-420d-5a51-8a9b-3c35ad795385`
**Source type:** paper
**Pointer:** `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`
**R1-R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/comm-reversal-4wk-xngusd_card.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-27 | Initial build from card | pending branch commit |
