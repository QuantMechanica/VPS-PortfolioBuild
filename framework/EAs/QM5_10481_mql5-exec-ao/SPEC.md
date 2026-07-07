# QM5_10481_mql5-exec-ao - Strategy Spec

**EA ID:** QM5_10481
**Slug:** `mql5-exec-ao`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

At each new M15 bar, the EA computes Awesome Oscillator as SMA(5, median price) minus SMA(34, median price) on completed bars. It buys when the latest completed AO value is sufficiently away from zero and AO bends upward, meaning AO[0] > AO[1] and AO[1] < AO[2]. It sells on the symmetric downward bend, uses a 1.5 x ATR(14) stop, sets a 2R target, and closes on an opposite AO bend or after 24 M15 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_work_tf` | `PERIOD_M15` | M15-H1 baseline | Timeframe used for AO, ATR, and time-stop bar counting. |
| `strategy_ao_fast_period` | 5 | 1-100 | Fast SMA period for the median-price AO calculation. |
| `strategy_ao_slow_period` | 34 | 2-200 | Slow SMA period for the median-price AO calculation. |
| `strategy_min_indent_atr_mult` | 0.10 | 0.0-5.0 | Minimum absolute AO distance from zero, expressed as an ATR multiple. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used for the minimum AO indent and stop distance. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | Stop-loss distance as an ATR multiple. |
| `strategy_target_rr` | 2.0 | 0.5-10.0 | Take-profit multiple of initial risk. |
| `strategy_time_stop_bars` | 24 | 1-500 | Maximum number of working-timeframe bars to hold a trade. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` -- do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for the full DWX backtest matrix because the card is symbol-agnostic and `farmctl` fans out Q02 accordingly:**
- Forex: `AUDCAD.DWX`, `AUDCHF.DWX`, `AUDJPY.DWX`, `AUDNZD.DWX`, `AUDUSD.DWX`, `CADCHF.DWX`, `CADJPY.DWX`, `CHFJPY.DWX`, `EURAUD.DWX`, `EURCAD.DWX`, `EURCHF.DWX`, `EURGBP.DWX`, `EURJPY.DWX`, `EURNZD.DWX`, `EURUSD.DWX`, `GBPAUD.DWX`, `GBPCAD.DWX`, `GBPCHF.DWX`, `GBPJPY.DWX`, `GBPNZD.DWX`, `GBPUSD.DWX`, `NZDCAD.DWX`, `NZDCHF.DWX`, `NZDJPY.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`, `USDCHF.DWX`, `USDJPY.DWX`.
- Indices: `SP500.DWX` (backtest-only custom symbol), `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX`.
- Commodities: `XAUUSD.DWX`, `XAGUSD.DWX`, `XTIUSD.DWX`, `XNGUSD.DWX`.

**Explicitly NOT for:**
- Non-DWX symbols - registry and backtest artifacts require canonical `.DWX` symbols.
- Unavailable index or ETF aliases such as `SPY.DWX`, `SPX500.DWX`, and `ES.DWX` - they are not in the DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `20` |
| Typical hold time | `up to 24 M15 bars` |
| Expected drawdown profile | `oscillator reversal strategy with fixed ATR risk and 2R target` |
| Regime preference | `momentum-turn / oscillator reversal` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `forum / codebase`
**Pointer:** `https://www.mql5.com/en/code/22613`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10481_mql5-exec-ao.md`

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
| v1 | 2026-05-29 | Initial build from card | 23730b88-1d8c-427a-9410-2ea3cbd82d88 |
| v2 | 2026-07-07 | Expand registry/setfile universe to full DWX matrix for Q02 retry | board-advisor infra repair |
