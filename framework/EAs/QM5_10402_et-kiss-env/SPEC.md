# QM5_10402_et-kiss-env - Strategy Spec

**EA ID:** QM5_10402
**Slug:** et-kiss-env
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades M15 JPY FX pullbacks in the direction of the daily trend. It computes SMA(10), SMA(20), and SMA(50) on typical price and an envelope around SMA(10); a long requires the D1 close above D1 SMA(20), rising SMA(20) and SMA(50), a prior pullback to SMA(10) or the lower envelope, and a closed-bar cross back above SMA(10) with SMA(10) rising. Shorts use the symmetric rules. Stops use the larger of 10 pips and the opposite inner envelope distance, capped at 1.5 ATR(20), with a 1R target and a session-close exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_M15` | M5-M30 tested by card | Base signal timeframe. |
| `strategy_sma1_period` | `10` | 8-20 tested by card | Fast typical-price SMA used for envelope and hook/cross. |
| `strategy_sma2_period` | `20` | 20-50 tested by card | Middle typical-price SMA slope filter. |
| `strategy_sma3_period` | `50` | 50-100 tested by card | Slow typical-price SMA slope filter. |
| `strategy_d1_sma_period` | `20` | 20-50 tested by card | Daily trend filter SMA period. |
| `strategy_envelope_pct` | `0.15` | 0.10-0.25 | Percent envelope around SMA(10). |
| `strategy_stop_pips` | `10` | 10+ | Minimum fixed pip stop distance. |
| `strategy_atr_period` | `20` | 10-30 | ATR period for the stop cap. |
| `strategy_atr_stop_cap` | `1.5` | 1.0-1.5 | Maximum stop distance as ATR multiple. |
| `strategy_take_profit_rr` | `1.0` | 1.0-1.5 | Take-profit multiple of initial risk. |
| `strategy_session_start_h` | `7` | 0-23 | Broker hour when London/NY trading window opens. |
| `strategy_session_end_h` | `21` | 1-24 | Broker hour when positions are closed and new entries stop. |
| `strategy_max_spread_sl_frac` | `0.15` | 0.0-0.5 | Maximum spread as a fraction of stop distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `CADJPY.DWX` - JPY FX cross named in the approved card and present in the DWX matrix.
- `CHFJPY.DWX` - JPY FX cross named in the approved card and present in the DWX matrix.
- `EURJPY.DWX` - JPY FX cross named in the approved card and present in the DWX matrix.
- `GBPJPY.DWX` - JPY FX cross named in the approved card and present in the DWX matrix.

**Explicitly NOT for:**
- Non-JPY FX, indices, metals, and energy symbols - the card defines this baseline as an intraday FX JPY envelope pullback basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `D1` close versus `D1` SMA(20) trend filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Intraday, normally minutes to hours until 1R, stop, or session close |
| Expected drawdown profile | Moderate/high because the source is a forum thread narrowed to mechanical rules |
| Regime preference | Trend-continuation pullback during liquid London/NY FX hours |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/kiss-keep-it-simple-stupid-but-make-sure-you-still-have-an-edge.95971/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10402_et-kiss-env.md`

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
| v1 | 2026-05-25 | Initial build from card | 42244b3b-8d6e-4d18-ab0a-a5890b7edc0a |
