# QM5_10723_tv-tns-fvg - Strategy Spec

**EA ID:** QM5_10723
**Slug:** tv-tns-fvg
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades M5 index CFD taps into active fair value gaps. A bullish gap is formed when a closed bar's low is above the high two bars earlier; a bearish gap is formed when a closed bar's high is below the low two bars earlier. At least three bars after formation, the EA enters long after a bearish tap candle into a bullish gap, or short after a bullish tap candle into a bearish gap. The stop is ATR based, take profit is the nearest confirmed swing pivot in the trade direction, setups below 1.5R are skipped, stops move to breakeven plus a small lock after 0.8R, and positions are force-closed at session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_fvg_max_age | 30 | 3-100 | Maximum closed-bar age for a fair value gap to remain active. |
| strategy_min_tap_age | 3 | 1-20 | Minimum bars after gap formation before a tap can qualify. |
| strategy_pivot_length | 8 | 1-50 | Bars on each side required to confirm swing pivot targets. |
| strategy_atr_period | 14 | 2-100 | ATR period used for the baseline stop distance. |
| strategy_stop_atr_mult | 0.75 | 0.1-10.0 | ATR multiplier used for the uncapped stop distance. |
| strategy_stop_atr_cap_mult | 2.5 | 0.1-10.0 | ATR multiplier cap for the stop distance unless broker minimum is wider. |
| strategy_min_rr | 1.5 | 0.5-10.0 | Minimum reward-to-risk ratio required for a setup. |
| strategy_be_trigger_r | 0.8 | 0.1-5.0 | Profit in R before moving stop to breakeven plus lock. |
| strategy_be_lock_points | 5 | 0-1000 | Points locked beyond entry after the breakeven trigger. |
| strategy_filter_weak_sl | true | true/false | Skip setups where the stop would remain inside the tapped FVG. |
| strategy_edge_offset_points | 0 | 0-1000 | Extra points required inside FVG edges for tap-candle clearance. |
| strategy_max_trades_per_day | 3 | 1-20 | Maximum entry attempts per broker day. |
| strategy_use_symbol_session | true | true/false | Use broker-time regular-session defaults by symbol, with GDAXI.DWX mapped to the DAX cash session. |
| strategy_session_start_hhmm | 1630 | 0000-2359 | Broker-time fallback session start, mapped from US index regular session. |
| strategy_entry_cutoff_hhmm | 2230 | 0000-2359 | Broker-time fallback no-new-entry cutoff, mapped from 15:30 ET. |
| strategy_session_end_hhmm | 2300 | 0000-2359 | Broker-time fallback forced-flat session end, mapped from 16:00 ET. |
| strategy_max_spread_points | 0 | 0-100000 | Optional spread ceiling in points; 0 disables the spread gate. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq 100 index CFD, directly named in the approved card.
- SP500.DWX - S&P 500 custom symbol, directly aligned with the card's US index target and valid for backtest registration.
- GDAXI.DWX - Verified DWX DAX symbol used for the card's GER40.DWX target because GER40.DWX is not in the DWX matrix.
- WS30.DWX - Dow 30 index CFD, directly named in the approved card.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; ported to GDAXI.DWX.
- SPX500.DWX, SPY.DWX, ES.DWX - Not canonical available DWX S&P 500 names; SP500.DWX is the approved custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Intraday session scalp; minutes to same-day session close |
| Expected drawdown profile | Many small ATR-defined losses with capped session exposure |
| Regime preference | Retest-continuation after fair value gap formation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy script
**Pointer:** https://www.tradingview.com/script/m0FwlCdM-Tap-n-Slap-TnS-optimized/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10723_tv-tns-fvg.md`

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
| v1 | 2026-06-02 | Initial build from card | a85279dc-95c3-4911-b47e-bea925e21943 |
| v2 | 2026-06-17 | Rebuild from approved card with symbol-session defaults | c896e7a8-63cb-457d-a77a-1cc5ddd33ca0 |
| v3 | 2026-06-18 | Build validation and smoke handoff | 64f4ecae-a324-4e0f-91ef-db0c7c767946 |
| v4 | 2026-06-18 | Build validation and smoke handoff | f74c2d1f-f7b8-475f-8401-a4becf99c732 |
