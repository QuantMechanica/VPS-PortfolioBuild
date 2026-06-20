# QM5_11553_carter-t-m5-cci14-macd1269 - Strategy Spec

**EA ID:** QM5_11553
**Slug:** carter-t-m5-cci14-macd1269
**Source:** 42530cb3-0265-534a-89cc-150f80733ff5 (see `strategy-seeds/sources/42530cb3-0265-534a-89cc-150f80733ff5/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades a five-minute CCI breakout confirmed by MACD direction. A long signal opens when CCI(14) crosses up through +100 on the last closed M5 bar, MACD signal is below MACD main on that bar, and MACD main is higher than on the prior closed bar. A short signal opens when CCI(14) crosses down through -100, MACD signal is above MACD main, and MACD main is lower than on the prior closed bar. Positions exit only through the fixed 13 pip stop, fixed 8 pip take profit, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_cci_period` | 14 | 2-100 | CCI lookback period. |
| `strategy_cci_level` | 100.0 | 50-200 | Positive and negative CCI breakout threshold. |
| `strategy_macd_fast` | 12 | 2-50 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | 3-100 | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 2-50 | MACD signal period. |
| `strategy_sl_pips` | 13 | 1-15 | Fixed stop-loss distance in pips. |
| `strategy_tp_pips` | 8 | 1-30 | Fixed take-profit distance in pips. |
| `strategy_spread_cap_pips` | 5 | 0-20 | Maximum genuine spread in pips before new trading is blocked. |
| `strategy_no_friday_entry` | true | true/false | Blocks new entries on Friday broker time. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - listed in the card's R3 PASS section for M5 DWX history and matches the source strategy's EUR/USD TP.
- `GBPUSD.DWX` - listed in the card's R3 PASS section for M5 DWX history and is the second portable major-FX pair.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the card specifies a five-minute forex setup with fixed pip SL/TP.
- FX pairs outside the R3 row - not registered for P2 because the approved card only names EURUSD.DWX and GBPUSD.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 300 |
| Typical hold time | Intraday M5 scalping hold, usually minutes to a few hours. |
| Expected drawdown profile | Frequent small fixed-risk losses with tight 13 pip stops. |
| Regime preference | Momentum breakout / volatility expansion. |
| Win rate target (qualitative) | High enough to offset 13 pip risk versus 8 pip reward. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 42530cb3-0265-534a-89cc-150f80733ff5
**Source type:** book
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11553_carter-t-m5-cci14-macd1269.md`

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
| v1 | 2026-06-20 | Initial build from card | 8463213d-c87c-44ec-b04b-e4de89622e4d |
