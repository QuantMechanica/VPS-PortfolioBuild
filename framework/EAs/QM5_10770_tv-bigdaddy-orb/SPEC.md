# QM5_10770_tv-bigdaddy-orb - Strategy Spec

**EA ID:** QM5_10770
**Slug:** `tv-bigdaddy-orb`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA builds an opening range from closed bars after the configured session start. In continuation mode it buys when a confirmed candle closes above the range high and sells when a confirmed candle closes below the range low. In reversal mode it buys after price breaks below the range and then closes back inside it, and sells after price breaks above the range and then closes back inside it. Stop loss is set at the configured range midpoint, opposite side, or failed-breakout wick, and take profit is a fixed R:R multiple.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_session_start_hhmm` | 930 | 0000-2359 | Broker-time session start used to begin opening-range construction. |
| `strategy_trading_window_minutes` | 120 | 5-1440 | Trading window length after session start when `strategy_use_full_session=false`. |
| `strategy_full_session_end_hhmm` | 1600 | 0000-2359 | Broker-time session end used when full-session mode is enabled. |
| `strategy_use_full_session` | false | true/false | Use the full session end instead of the first-N-minutes trading window. |
| `strategy_orb_window_minutes` | 15 | 5-60 | Opening range length in minutes. |
| `strategy_mode` | continuation | continuation/reversal/both | Enables continuation signals, reversal signals, or both. |
| `strategy_stop_mode` | midpoint | midpoint/opposite_side/failed_wick | Stop placement rule for new trades. |
| `strategy_rr_target` | 2.0 | >0 | Take-profit multiple of entry-to-stop risk. |
| `strategy_close_at_session_end` | true | true/false | Close open positions when the configured trading window ends. |
| `strategy_max_spread_points` | 0.0 | >=0 | Optional spread ceiling in points; 0 disables the spread ceiling. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX session pair listed in the card R3 basket.
- `GBPUSD.DWX` - FX session pair listed in the card R3 basket.
- `USDJPY.DWX` - FX session pair listed in the card R3 basket.
- `XAUUSD.DWX` - Gold/metals session symbol; registered with the required `.DWX` suffix.
- `GDAXI.DWX` - Available DAX custom symbol; used as the DWX equivalent for card-stated `GER40.DWX`.
- `NDX.DWX` - Nasdaq 100 index CFD listed in the card R3 basket.
- `WS30.DWX` - Dow 30 index CFD listed in the card R3 basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the available DAX custom symbol.
- `XAUUSD` - unsuffixed name is not registered for backtests; `XAUUSD.DWX` is used.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` and `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `220` |
| Typical hold time | Intraday, from breakout entry until RR target, stop loss, or session-end close. |
| Expected drawdown profile | Breakout/reversal system with clustered losses during range-bound false starts. |
| Regime preference | Session-bound volatility expansion and failed-breakout reversal regimes. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy`
**Pointer:** `https://www.tradingview.com/script/2uttfmSo-Big-Daddy-Max-ORB-Strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10770_tv-bigdaddy-orb.md`

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
| v1 | 2026-05-31 | Initial build from card | b06efbea-3656-4ef8-93ee-33f2806c7fde |
