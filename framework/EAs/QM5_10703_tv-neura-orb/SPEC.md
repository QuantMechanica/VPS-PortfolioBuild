# QM5_10703_tv-neura-orb — Strategy Spec

**EA ID:** QM5_10703
**Slug:** tv-neura-orb
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA builds the New York opening range from 09:30 to 09:45 Eastern using closed bars. After the range is complete, a long signal fires when the prior close was at or below the range high and the latest close is above it; shorts mirror this below the range low. In retest mode the first breakout only arms the direction, then the EA waits for price to touch the broken range boundary and close back on the breakout side. Exits use a fixed R:R target from the selected stop, a maximum 80-bar time stop, and a New York session flat time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_or_start_ny_hhmm | 930 | 0000-2359 | New York opening-range start time. |
| strategy_or_duration_minutes | 15 | >0 | Opening-range length in minutes. |
| strategy_trade_cutoff_ny_hhmm | 1555 | 0000-2359 | Last New York time at which a fresh entry may be considered. |
| strategy_session_close_ny_hhmm | 1600 | 0000-2359 | New York time when open positions are flattened. |
| strategy_entry_type | 0 | 0-1 | 0 enters on breakout close; 1 waits for retest rejection. |
| strategy_stop_method | 0 | 0-2 | 0 opposite OR side; 1 OR midpoint; 2 ATR stop. |
| strategy_atr_period | 14 | >0 | ATR period for ATR stop and FVG size. |
| strategy_atr_stop_mult | 1.5 | >0 | ATR multiplier for stop method 2. |
| strategy_rr_target | 1.5 | >0 | Take-profit multiple of entry risk. |
| strategy_time_exit_bars | 80 | >=0 | Maximum holding period in chart bars; 0 disables. |
| strategy_volume_filter_enabled | false | bool | Enables tick-volume confirmation. |
| strategy_volume_sma_period | 20 | >0 | Tick-volume SMA lookback. |
| strategy_volume_sma_mult | 1.2 | >0 | Required volume multiple over SMA. |
| strategy_fvg_filter_enabled | false | bool | Enables breakout-bar FVG confirmation. |
| strategy_fvg_min_atr_mult | 0.3 | >0 | Minimum FVG size as ATR multiple. |
| strategy_max_spread_points | 0 | >=0 | Maximum spread in points; 0 disables. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX — Nasdaq 100 index CFD matches the card's index-CFD ORB target.
- WS30.DWX — Dow 30 index CFD adds a liquid US index baseline.
- GDAXI.DWX — DAX 40 matrix-backed equivalent for the card's GER40 target.
- XAUUSD.DWX — gold is explicitly included in the card's ORB universe.
- EURUSD.DWX — FX pair included in the card's primary P2 basket.

**Explicitly NOT for:**
- GER40.DWX — not present in `dwx_symbol_matrix.csv`; GDAXI.DWX is used instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Typical hold time | Intraday, capped at 80 bars or session close |
| Expected drawdown profile | Spread and slippage sensitive intraday breakout losses during false OR breaks |
| Regime preference | Volatility-expansion breakout |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source indicator
**Pointer:** https://www.tradingview.com/script/Sb0YgLYU-NeuraEdge-ORB-Opening-Range-Breakout-Indicator/
**R1–R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10703_tv-neura-orb.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-31 | Initial build from card | aeda5eec-cfbf-46d9-beeb-57f0e52c5850 |
