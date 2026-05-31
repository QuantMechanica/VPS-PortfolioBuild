# QM5_10594_mql5-beginner - Strategy Spec

**EA ID:** QM5_10594
**Slug:** `mql5-beginner`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `sources/mql5-codebase-mt5-strategies`)
**Author of this spec:** Codex
**Last revised:** 2026-05-30

---

## 1. Strategy Logic

This EA trades the MQL5 Beginner color-point reversal rule on completed H4 bars. A bullish point is generated when the closed bar finishes near the upper edge of the recent 9-bar range using the source default 30 percent threshold; a bearish point is generated when it finishes near the lower edge. The EA opens long on a bullish point, opens short on a bearish point, closes on the opposite point, and also closes after 16 completed H4 bars if no opposite point has appeared.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_beginner_period` | 9 | 1-100 | Recent bar range used by the Beginner color-point threshold. |
| `strategy_beginner_shift_pct` | 30.0 | 1.0-99.0 | Percent of the recent range used as the upper/lower signal zone. |
| `strategy_range_period` | 10 | 1-100 | Source Beginner warmup/range period retained for default compatibility. |
| `strategy_atr_period` | 14 | 2-100 | ATR lookback for the catastrophic stop and optional body filter. |
| `strategy_atr_sl_mult` | 2.5 | 0.1-20.0 | ATR multiple used for the catastrophic stop from entry. |
| `strategy_time_stop_bars` | 16 | 1-200 | Maximum completed H4 bars to hold a position. |
| `strategy_suppress_prior_repeats` | true | true/false | Suppresses same-direction continuation points if the prior closed bar already had that point. |
| `strategy_use_body_filter` | false | true/false | Optional P3 filter; disabled in baseline. |
| `strategy_min_body_atr` | 0.25 | 0.0-5.0 | Minimum signal-bar body as ATR fraction when the optional body filter is enabled. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `USDCHF.DWX` - primary source analog from the published USDCHF H4 test.
- `EURUSD.DWX` - DWX FX major with the same H4 closed-bar reversal mechanics.
- `GBPUSD.DWX` - DWX FX major included by the approved card as a portability symbol.
- `USDJPY.DWX` - DWX FX major included by the approved card as a portability symbol.

**Explicitly NOT for:**
- Non-DWX symbols - the framework and registries require canonical `.DWX` symbols for research and backtest.
- Equity index or commodity CFDs - the approved card names an FX majors/crosses baseline, not a cross-asset basket.

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
| Trades / year / symbol | 80 |
| Typical hold time | Up to 16 completed H4 bars, shorter on opposite color point |
| Expected drawdown profile | Reversal system with ATR-catastrophic stop, no take-profit and no trailing |
| Regime preference | Reversal / closed-bar semaphore signals |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/1443` and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10594_mql5-beginner.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10594_mql5-beginner.md`

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
| v1 | 2026-05-30 | Initial build from card | 8abfac56-d8f0-4358-b9c0-805358d11eae |
