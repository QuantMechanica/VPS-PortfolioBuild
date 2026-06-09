# QM5_10206_tv-9ema-full-candle - Strategy Spec

**EA ID:** QM5_10206
**Slug:** `tv-9ema-full-candle`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades the first M5 candle that fully clears EMA(9). It enters long when the latest closed candle has `low > EMA(9)` and the prior closed candle did not, and enters short when the latest closed candle has `high < EMA(9)` and the prior closed candle did not. It exits a long when price crosses back below EMA(9), and exits a short when price crosses back above EMA(9). Each entry uses a fixed emergency stop at 2.0 * ATR(14), calculated at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_M5` | MT5 timeframe enum | Source timeframe for EMA and candle qualification |
| `strategy_ema_period` | `9` | `1+` | EMA period used for entry and exit |
| `strategy_atr_period` | `14` | `1+` | ATR period for emergency stop distance |
| `strategy_atr_sl_mult` | `2.0` | `>0` | ATR multiple for fixed emergency stop |
| `strategy_spread_stop_frac` | `0.10` | `0+` | Maximum spread as fraction of emergency stop distance |
| `strategy_us_start_hhmm` | `1630` | `0000-2359` | Broker-time start for US index liquid session |
| `strategy_us_end_hhmm` | `2300` | `0000-2359` | Broker-time end for US index liquid session |
| `strategy_overlap_start_hhmm` | `1500` | `0000-2359` | Broker-time start for London/New York overlap |
| `strategy_overlap_end_hhmm` | `1900` | `0000-2359` | Broker-time end for London/New York overlap |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol called by the card; backtest-only per DWX discipline.
- `NDX.DWX` - Nasdaq 100 live-tradable US large-cap index analog from the card.
- `WS30.DWX` - Dow 30 live-tradable US large-cap index analog from the card.
- `GDAXI.DWX` - Matrix-supported DAX symbol used for the card-stated `GER40.DWX`.
- `XAUUSD.DWX` - Gold symbol explicitly targeted by the card.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated name is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.
- Any symbol not registered above - magic resolution blocks unregistered symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `180` |
| Typical hold time | Intraday; exits on EMA cross-back |
| Expected drawdown profile | Fixed-risk losses bounded by 2.0 * ATR emergency stop |
| Regime preference | Intraday momentum / trend continuation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** `https://www.tradingview.com/script/aUCZlh4q-9-EMA-First-Full-Candle-Entry-EMA-Cross-Exit-Strategy/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10206_tv-9ema-full-candle.md`

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
| v1 | 2026-06-09 | Initial build from card | fa42802b-0eb0-49b6-bc7b-45a8d55f7206 |
