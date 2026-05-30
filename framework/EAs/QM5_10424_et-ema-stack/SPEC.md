# QM5_10424_et-ema-stack - Strategy Spec

**EA ID:** QM5_10424
**Slug:** `et-ema-stack`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades a completed-bar EMA stack crossover on H1. It goes long when EMA(20) crosses above EMA(50) and EMA(50) is above EMA(100), and goes short when EMA(20) crosses below EMA(50) and EMA(50) is below EMA(100). It exits an open long on the opposite EMA(20)/EMA(50) cross and exits an open short on the opposite cross; initial stop is 2.0 x ATR(20) and the optional target is 3.0 x ATR(20).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ema_period` | 20 | 1+ | Fast EMA period used for crossover trigger |
| `strategy_mid_ema_period` | 50 | 1+ | Mid EMA period used for crossover and stack filter |
| `strategy_slow_ema_period` | 100 | 1+ | Slow EMA period used as trend stack filter |
| `strategy_atr_period` | 20 | 1+ | ATR period for stop and target distance |
| `strategy_atr_sl_mult` | 2.0 | >0 | Stop distance in ATR multiples |
| `strategy_atr_tp_mult` | 3.0 | >=0 | Target distance in ATR multiples when target is enabled |
| `strategy_use_atr_target` | true | true/false | Enables the optional ATR target from the card |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed liquid FX symbol with OHLC EMA/ATR data.
- `GBPUSD.DWX` - Card-listed liquid FX symbol with OHLC EMA/ATR data.
- `XAUUSD.DWX` - Card-listed metal symbol with OHLC EMA/ATR data.
- `SP500.DWX` - Card-listed S&P 500 custom symbol; valid for backtest, not live-routable.
- `NDX.DWX` - Card-listed Nasdaq 100 index symbol with OHLC EMA/ATR data.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified DWX test data.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | hours to days |
| Expected drawdown profile | Whipsaw-prone in ranges; controlled by ATR stop. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/queries-on-afl.229807/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10424_et-ema-stack.md`

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
| v1 | 2026-05-25 | Initial build from card | 1ad2eb7f-fcd4-48fe-9b5a-0ad1fef08b81 |
