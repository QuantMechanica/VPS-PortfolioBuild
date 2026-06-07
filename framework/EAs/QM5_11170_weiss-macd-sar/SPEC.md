# QM5_11170_weiss-macd-sar - Strategy Spec

**EA ID:** QM5_11170
**Slug:** weiss-macd-sar
**Source:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6 (see `strategy-seeds/sources/3005c768-aa91-5daf-9dd7-500d7bfcb7a6/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed D1 bars. It enters long when MACD(13,26) crosses above its 9-period signal line and the signal line is above zero; it enters short when MACD(13,26) crosses below its 9-period signal line and the signal line is below zero. An opposite qualified MACD cross closes the current position, and the same closed-bar event can open the reverse side. There is no profit target; every entry carries a catastrophic protective stop at the greater of 3 x ATR(20,D1) and the broker minimum stop distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast_period` | 13 | 10-16 P3 sweep, default 13 | Fast EMA period used by MACD. |
| `strategy_macd_slow_period` | 26 | 22-32 P3 sweep, default 26 | Slow EMA period used by MACD. |
| `strategy_macd_signal_period` | 9 | 7-11 P3 sweep, default 9 | Signal-line EMA period used by MACD. |
| `strategy_atr_period` | 20 | fixed default 20 | D1 ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | 3.0 | fixed default 3.0 | ATR multiplier for the catastrophic stop. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair in the card's P2 basket.
- `USDJPY.DWX` - liquid major FX pair in the card's P2 basket.
- `XAUUSD.DWX` - liquid gold CFD in the card's P2 basket.
- `XTIUSD.DWX` - liquid crude oil CFD in the card's P2 basket.
- `SP500.DWX` - available S&P 500 custom symbol in the card's P2 basket; backtest-only at later live gates.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - the broker/custom-symbol data surface is not available for P2.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 2 |
| Typical hold time | about 143 days average hold cited in the card |
| Expected drawdown profile | low-turnover trend-following drawdowns from long holds through adverse swings |
| Regime preference | trend |
| Win rate target (qualitative) | low to medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Source type:** book
**Pointer:** Richard L. Weissman, Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis, Wiley, 2005, Chapter 3, pp. 55-56, https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11170_weiss-macd-sar.md`

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
| v1 | 2026-06-07 | Initial build from card | a371131f-1a21-4e53-9e57-fa5187ee97c8 |
