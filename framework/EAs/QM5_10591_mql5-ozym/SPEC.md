# QM5_10591_mql5-ozym - Strategy Spec

**EA ID:** QM5_10591
**Slug:** mql5-ozym
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-30

---

## 1. Strategy Logic

The EA trades closed-bar Ozymandias middle-line color changes on the chart timeframe. A bullish color change opens a long position and a bearish color change opens a short position, with only one active position per symbol and magic. An open long closes on the next bearish color change, and an open short closes on the next bullish color change. Hard exits are the card baseline ATR stop, 1.5R target, and the V5 framework kill-switch, Friday close, and news handling.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ozymandias_length` | 2 | 2+ | Ozymandias high/low SMA length from the source indicator default. |
| `strategy_ozymandias_lookback_bars` | 240 | 20+ | Bounded warmup window for reconstructing the closed-bar Ozymandias trend state. |
| `strategy_atr_period` | 14 | 1+ | ATR period for the hard stop. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiplier for the hard stop. |
| `strategy_rr_target` | 1.5 | >0 | Reward-to-risk multiple for the hard target. |
| `strategy_use_atr_floor` | false | true/false | Optional ATR-volatility floor switch from the card. |
| `strategy_min_atr_points` | 0.0 | >=0 | Minimum ATR in points when the optional ATR floor is enabled. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - card primary source-test family and R3 P2 basket member.
- `EURUSD.DWX` - liquid major FX pair named in the approved R3 basket.
- `USDJPY.DWX` - liquid major FX pair named in the approved R3 basket.
- `XAUUSD.DWX` - liquid metal CFD named in the approved R3 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - unavailable to the DWX backtest matrix.

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
| Trades / year / symbol | 40 |
| Typical hold time | several H4 bars to multiple days |
| Expected drawdown profile | moderate trend-following whipsaw risk around color changes |
| Regime preference | trend / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/12543
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10591_mql5-ozym.md`

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
| v1 | 2026-05-30 | Initial build from card | 7f022dba-0d8c-416b-9746-46a2561accd4 |
