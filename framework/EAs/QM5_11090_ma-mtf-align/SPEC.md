# QM5_11090_ma-mtf-align - Strategy Spec

**EA ID:** QM5_11090
**Slug:** ma-mtf-align
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86 (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed H1 bars and reads SMA alignment on H1, H4, and D1. A long entry is allowed when the last closed price is above SMA(25) on every enabled timeframe and the previous aggregate state was not fully above. A short entry is allowed when the last closed price is below SMA(25) on every enabled timeframe and the previous aggregate state was not fully below. Long positions close when any enabled timeframe is no longer above its SMA; short positions close when any enabled timeframe is no longer below its SMA.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ma_period | 25 | 2+ | SMA period used for all enabled timeframe alignment checks. |
| strategy_ma_price | PRICE_CLOSE | MT5 applied price enum | Applied price for the SMA alignment rule. |
| strategy_use_h1 | true | true / false | Include H1 in the aggregate alignment check. |
| strategy_use_h4 | true | true / false | Include H4 in the aggregate alignment check. |
| strategy_use_d1 | true | true / false | Include D1 in the aggregate alignment check. |
| strategy_atr_period | 14 | 1+ | ATR period for the protective stop. |
| strategy_atr_sl_mult | 2.5 | 1.5-4.0 P3 sweep range | ATR multiple used for the initial stop loss. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card R3 names this forex major in the primary P2 basket.
- GBPUSD.DWX - Card R3 names this forex major in the primary P2 basket.
- USDJPY.DWX - Card R3 names this forex major in the primary P2 basket.
- XAUUSD.DWX - Card R3 names gold in the primary P2 basket; the rule uses OHLC-derived moving averages and ATR.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - build discipline forbids non-matrix symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | H1, H4, D1 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Expected trade frequency | MTF MA alignment on H1 should rotate a few times per month; conservative estimate 30 trades/year/symbol. |
| Typical hold time | Not specified in card; expected to last until the next loss of H1/H4/D1 alignment or ATR stop. |
| Expected drawdown profile | Trend-following whipsaw risk around SMA(25) alignment transitions. |
| Regime preference | Multi-timeframe trend alignment. |
| Win rate target (qualitative) | Not specified in card. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub repository and MQL5 source
**Pointer:** https://github.com/EarnForex/MA-Multi-Timeframe and `MQL5/Indicators/MQLTA MT5 MA Multi-Timeframe.mq5`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11090_ma-mtf-align.md`

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
| v1 | 2026-06-07 | Initial build from card | 75667799-2361-4ef0-8c10-74d47ba85456 |
