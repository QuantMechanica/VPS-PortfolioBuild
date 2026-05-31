# QM5_10489_mql5-trendmgr - Strategy Spec

**EA ID:** QM5_10489
**Slug:** mql5-trendmgr
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades the closed-bar TrendManager color-change rule from the approved card. It ports the published TrendManager defaults as a fast SMA(23) minus slow SMA(84) close-price spread, with a colored bullish state when the spread is at least 70 points and a bearish state when it is at most -70 points. A long opens when the latest closed bar changes into the bullish state or appears from neutral; a short opens on the bearish equivalent. Positions close on an opposite closed-bar color change, after 1200 minutes of holding time, or through the initial 1.5x ATR(14) stop and 2.0R take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_sma_period` | 23 | >=1 | Fast TrendManager moving-average length from source defaults. |
| `strategy_slow_sma_period` | 84 | >=1 | Slow TrendManager moving-average length from source defaults. |
| `strategy_dv_limit_points` | 70 | >=0 | Minimum fast-slow spread in symbol points required for a colored bar. |
| `strategy_atr_period` | 14 | >=1 | ATR period for the protective stop. |
| `strategy_atr_sl_mult` | 1.5 | >0 | ATR multiplier for initial stop distance. |
| `strategy_take_profit_rr` | 2.0 | >0 | Take-profit multiple of initial risk. |
| `strategy_max_hold_minutes` | 1200 | >=0 | Fixed maximum holding time in minutes; 0 disables the time stop. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - source example was GBPJPY H4 and the pair is in the DWX matrix.
- `EURUSD.DWX` - liquid major FX pair in the card's R3 basket.
- `GBPUSD.DWX` - liquid major FX pair in the card's R3 basket.
- `XAUUSD.DWX` - liquid metal symbol in the card's R3 basket.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline artifacts must use the registered `.DWX` symbol universe.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol data guarantee exists.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | Up to 1200 minutes unless opposite signal, SL, or TP exits first |
| Expected drawdown profile | ATR-bounded trend/color-change system with one active position per symbol and magic |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/21998
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10489_mql5-trendmgr.md`

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
| v1 | 2026-05-28 | Initial build from card | 5357be57-5050-4b28-b077-0b7b06a96853 |
