# QM5_10241_tv-vwap-retest - Strategy Spec

**EA ID:** QM5_10241
**Slug:** `tv-vwap-retest`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades an intraday continuation pattern around the session VWAP. A long setup starts when a closed bar first breaks above the current session VWAP; within the configured retest window, a later closed bar must touch back toward VWAP, close bullish above VWAP, show a rejection wick, and satisfy the tick-volume spike filter. Shorts mirror the same sequence below VWAP when enabled. Exits are the ATR stop, ATR target, framework Friday close, and the optional session-close flat rule.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_session_start_hour` | 8 | 0-23 | Broker hour when the VWAP trading session starts. |
| `strategy_session_end_hour` | 21 | 0-23 | Broker hour when new entries stop and optional flat close begins. |
| `strategy_session_close_flat` | true | true/false | Close open EA positions after the session end hour. |
| `strategy_allow_shorts` | true | true/false | Enable the mirrored short setup below VWAP. |
| `strategy_atr_period` | 14 | 1-100 | ATR lookback for stop and target distance. |
| `strategy_atr_sl_mult` | 1.0 | 0.1-10.0 | Stop-loss distance in ATR multiples. |
| `strategy_atr_tp_mult` | 1.5 | 0.1-20.0 | Take-profit distance in ATR multiples. |
| `strategy_retest_max_bars` | 6 | 1-50 | Maximum bars allowed between VWAP break and retest confirmation. |
| `strategy_max_trades_per_day` | 2 | 1-20 | Maximum new entries per symbol per broker day. |
| `strategy_volume_lookback` | 20 | 1-128 | Closed-bar tick-volume average lookback. |
| `strategy_volume_spike_mult` | 1.2 | 0.0-10.0 | Current tick volume must exceed prior average by this multiplier. |
| `strategy_rejection_wick_frac` | 0.30 | 0.0-1.0 | Required confirming wick fraction of the bar range. |
| `strategy_retest_tolerance_atr` | 0.15 | 0.0-2.0 | VWAP retest tolerance in ATR multiples. |
| `strategy_min_vwap_distance_atr` | 0.0 | 0.0-5.0 | Optional minimum breakout distance from VWAP in ATR multiples. |
| `strategy_max_spread_points` | 80 | 0-10000 | Spread ceiling for new entries; 0 disables the filter. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*) are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 intraday index port named by the card.
- `WS30.DWX` - Dow 30 intraday index port named by the card.
- `GDAXI.DWX` - Verified DWX DAX custom symbol; used as the canonical port for the card's `GER40.DWX` wording.
- `XAUUSD.DWX` - Gold CFD port named by the card.
- `EURUSD.DWX` - Major FX port named by the card.
- `SP500.DWX` - S&P 500 analog named by the card; valid for backtest only per DWX discipline.

**Explicitly NOT for:**
- Any symbol absent from `framework/registry/dwx_symbol_matrix.csv` - the framework magic resolver will not authorize it for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none; H1 bias is left disabled for P3 parameter work per the card |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Intraday, from retest confirmation to ATR target/stop or session close |
| Expected drawdown profile | Bounded by fixed $1,000 backtest risk per trade and one open position per magic number |
| Regime preference | Intraday continuation after VWAP break and retest |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script page
**Pointer:** `https://www.tradingview.com/script/9dkGK2jB-VWAP-Reversal-Strategy-V1/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10241_tv-vwap-retest.md`

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
| v1 | 2026-06-09 | Initial build from card | 4d090163-9fd3-4e87-a641-511c0c00648c |
