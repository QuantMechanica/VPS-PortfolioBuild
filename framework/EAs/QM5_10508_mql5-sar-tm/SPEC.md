# QM5_10508_mql5-sar-tm - Strategy Spec

**EA ID:** QM5_10508
**Slug:** `mql5-sar-tm`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates Parabolic SAR on closed H4 bars. It opens long when the just-closed bar changes from bearish SAR state to bullish SAR state, and opens short when the just-closed bar changes from bullish SAR state to bearish SAR state. Each trade has a hard stop at 1.5 times ATR(14), a target at 1.5R, and no added trade management beyond the initial bracket. It closes an open position when the closed-bar SAR state turns opposite or when the position has been held for at least 240 minutes.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H4` | H4 baseline | Timeframe used for SAR state and flip detection. |
| `strategy_sar_step` | `0.02` | `> 0` | Parabolic SAR acceleration step. |
| `strategy_sar_maximum` | `0.20` | `> 0` | Parabolic SAR maximum acceleration. |
| `strategy_hold_minutes` | `240` | `0+` | Fixed time exit in minutes; zero disables the time exit. |
| `strategy_atr_period` | `14` | `1+` | ATR period for the hard stop distance. |
| `strategy_atr_sl_mult` | `1.50` | `> 0` | Stop-loss distance as ATR multiple. |
| `strategy_target_rr` | `1.50` | `> 0` | Take-profit as reward-to-risk multiple from entry to stop. |
| `strategy_sar_warmup_bars` | `250` | `20+` | Closed-bar history used to initialise the SAR state calculation. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Major FX pair in the card's portable P2 basket.
- `GBPUSD.DWX` - Major FX pair in the card's portable P2 basket.
- `USDJPY.DWX` - Major FX pair in the card's portable P2 basket.
- `XAUUSD.DWX` - Liquid metal symbol in the card's portable P2 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not valid DWX backtest targets for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | Fixed 240-minute time exit or earlier opposite SAR flip / SL / TP |
| Expected drawdown profile | ATR-normalized trend-following losses during choppy SAR flips. |
| Regime preference | trend-change / trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/20629`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10508_mql5-sar-tm.md`

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
| v1 | 2026-05-28 | Initial build from card | a6577c1e-713d-484c-9300-aba9cc0f24c4 |
