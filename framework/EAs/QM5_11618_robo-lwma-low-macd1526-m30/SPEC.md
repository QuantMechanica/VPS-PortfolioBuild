# QM5_11618_robo-lwma-low-macd1526-m30 - Strategy Spec

**EA ID:** QM5_11618
**Slug:** robo-lwma-low-macd1526-m30
**Source:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d (see `sources/362359657-robo-forex-strategy`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades the M30 LWMA + MACD setup from the approved RoboForex card. A long entry requires the last closed price to be above WMA(75,Low) and WMA(85,Low), WMA(5,Low) to be above WMA(75,Low), and MACD(15,26,1) to cross above zero on the closed bar. A short entry requires price below WMA(75,Low), WMA(5,Low) below WMA(75,Low), and MACD(15,26,1) crossing below zero. Long stops are placed at WMA(85,Low); short stops use 2 x ATR(14); all targets use 4 x ATR(14), with no discretionary exit beyond SL/TP and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_wma_fast_period` | 5 | 2-200 | Fast LWMA period applied to low prices. |
| `strategy_wma_mid_period` | 75 | 2-300 | Middle LWMA period for the trend band. |
| `strategy_wma_outer_period` | 85 | 2-300 | Outer LWMA period used for long stop placement. |
| `strategy_macd_fast` | 15 | 2-100 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | 3-150 | MACD slow EMA period. |
| `strategy_macd_signal` | 1 | 1-50 | MACD signal period from the card. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for short stops and all targets. |
| `strategy_short_sl_atr_mult` | 2.0 | 0.1-20.0 | Short stop distance as ATR multiple. |
| `strategy_tp_atr_mult` | 4.0 | 0.1-40.0 | Target distance as ATR multiple. |
| `strategy_spread_pct_of_stop` | 15.0 | 0.0-100.0 | Blocks only genuinely wide modeled spreads relative to stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - FX major explicitly listed in the card and available in the DWX matrix.
- GBPUSD.DWX - FX major explicitly listed in the card and available in the DWX matrix.
- USDJPY.DWX - FX major explicitly listed in the card and available in the DWX matrix.
- USDCHF.DWX - FX major explicitly listed in the card and available in the DWX matrix.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research and backtest artifacts must use canonical `.DWX` symbols.
- Equity index and commodity CFDs - the card's R3 universe is the four listed FX majors.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | hours |
| Expected drawdown profile | Moderate trend-following drawdown from false MACD zero-crosses around the LWMA band. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
**Source type:** educational PDF
**Pointer:** RoboForex Educational Team, `362359657-Robo-forex-strategy.pdf`, page 54, strategy "LWMA + MACD".
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11618_robo-lwma-low-macd1526-m30.md`

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
| v1 | 2026-06-26 | Initial build from card | 7f0550a6-56b3-4e81-93ec-02bd17d6e2da |
