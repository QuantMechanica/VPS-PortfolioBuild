# QM5_10364_et-lbr-310 - Strategy Spec

**EA ID:** QM5_10364
**Slug:** `et-lbr-310`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades the first MACD 3/10/16 signal-line zero cross, then waits for the MACD histogram to pull back through zero and turn back toward the new signal-line direction on a closed M1 bar. Long entries require the signal line above zero, a negative histogram pullback turning upward, and EMA(9) above EMA(34) when the optional EMA filter is enabled. Short entries mirror the rule with the signal line below zero, a positive histogram pullback turning downward, and EMA(9) below EMA(34). Initial stop and target are symmetric at 0.25 x ATR(14), stop is moved to breakeven after 0.75R, and any open position is closed outside the configured regular-session window.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_macd_fast` | 3 | 1-50 | MACD fast EMA period. |
| `strategy_macd_slow` | 10 | 2-100 | MACD slow EMA period; must be greater than fast. |
| `strategy_macd_signal` | 16 | 1-100 | MACD signal-line period used as the source 16-line proxy. |
| `strategy_ema_filter_enabled` | true | true/false | Enables the optional EMA trend filter from the card. |
| `strategy_ema_fast` | 9 | 1-100 | Fast EMA period for direction filter. |
| `strategy_ema_slow` | 34 | 2-200 | Slow EMA period for direction filter. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for target and stop distance. |
| `strategy_atr_target_mult` | 0.25 | 0.05-2.00 | ATR multiplier for symmetric stop and target. |
| `strategy_breakeven_trigger_r` | 0.75 | 0.00-2.00 | R multiple where stop moves to breakeven. |
| `strategy_session_start_hhmm` | 1530 | 0000-2359 | Broker-time start of regular index session trading. |
| `strategy_session_end_hhmm` | 2200 | 0000-2359 | Broker-time end of regular index session trading and session-close exit. |
| `strategy_spread_filter_enabled` | true | true/false | Enables the spread filter. |
| `strategy_spread_window` | 21 | 3-101 | Rolling spread sample count for median spread estimate. |
| `strategy_spread_median_mult` | 2.5 | 1.0-10.0 | Blocks entries when spread exceeds this multiple of rolling median spread. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - Closest available ES/S&P 500 backtest proxy named in the approved card.
- `NDX.DWX` - Liquid US large-cap index CFD live-port candidate named in the approved card.
- `WS30.DWX` - Liquid US large-cap index CFD live-port candidate named in the approved card.
- `GDAXI.DWX` - Verified DAX custom symbol in `dwx_symbol_matrix.csv`; used as the available DWX port for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - Card-stated DAX label, but not present in `dwx_symbol_matrix.csv`; no registry row was created for this unavailable name.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - Unavailable S&P/ES variants; `SP500.DWX` is the canonical custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework `OnTick` entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `250` |
| Typical hold time | Intraday scalp; minutes to session-close maximum |
| Expected drawdown profile | Tight symmetric stop/target means frequent small losses during chop and spread/slippage sensitivity |
| Regime preference | Intraday momentum-pullback after a fresh MACD zero-line regime shift |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/free-es-trading-strategy-that-works.162375/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10364_et-lbr-310.md`

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
| v1 | 2026-05-25 | Initial build from card | 6d26e3bc-c52a-4582-8b80-e9c6e261efa6 |
