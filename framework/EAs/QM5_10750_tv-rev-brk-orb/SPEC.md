# QM5_10750_tv-rev-brk-orb - Strategy Spec

**EA ID:** QM5_10750
**Slug:** `tv-rev-brk-orb`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This M5 EA trades a combined reversal, breakout, and opening range breakout rule. Reversal entries require price crossing SMA(50), RSI(14) at an extreme, price on the opposite side of broker-session VWAP, and SMA(200) slope in the trade direction. Breakout entries require EMA(9) and EMA(20) alignment, price on the correct side of VWAP, and SMA(200) slope confirmation. ORB entries require a close beyond the first 15 M5 bars' opening range with tick volume greater than 1.5 times opening-range average tick volume. Stops use the 7-bar structure extreme plus 1.5 ATR(14), with a full-position 2R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_enable_reversal` | `true` | `true/false` | Enable the SMA50/RSI/VWAP reversal submodel. |
| `strategy_enable_breakout` | `true` | `true/false` | Enable the EMA/VWAP/SMA200 breakout submodel. |
| `strategy_enable_orb` | `true` | `true/false` | Enable the opening range breakout submodel. |
| `strategy_ema_fast_period` | `9` | `>=1` | Fast EMA period for breakout alignment. |
| `strategy_ema_slow_period` | `20` | `>=1` | Slow EMA period for breakout alignment. |
| `strategy_sma_cross_period` | `50` | `>=1` | SMA period used for the reversal cross condition. |
| `strategy_sma_trend_period` | `200` | `>=2` | SMA period used for long/short trend context. |
| `strategy_rsi_period` | `14` | `>=1` | RSI period for reversal extremes. |
| `strategy_rsi_oversold` | `30.0` | `0-100` | Long reversal threshold. |
| `strategy_rsi_overbought` | `70.0` | `0-100` | Short reversal threshold. |
| `strategy_atr_period` | `14` | `>=1` | ATR period for structure stop padding. |
| `strategy_atr_stop_mult` | `1.5` | `>0` | ATR multiplier added to structure stop. |
| `strategy_structure_lookback` | `7` | `>=1` | Bars used for lowest-low/highest-high stop anchor. |
| `strategy_target_rr` | `2.0` | `>0` | Full-position fixed R multiple target. |
| `strategy_opening_range_bars` | `15` | `>=1` | M5 bars used to define the opening range. |
| `strategy_orb_volume_mult` | `1.5` | `>0` | Tick-volume multiple required for ORB entries. |
| `strategy_session_filter_enabled` | `true` | `true/false` | Restrict entries to the configured liquid session. |
| `strategy_session_start_hour` | `15` | `0-23` | Broker-time session start hour. |
| `strategy_session_start_minute` | `30` | `0-59` | Broker-time session start minute. |
| `strategy_session_end_hour` | `22` | `0-23` | Broker-time session end hour. |
| `strategy_session_end_minute` | `0` | `0-59` | Broker-time session end minute. |
| `strategy_max_spread_points` | `0` | `>=0` | Optional spread gate; `0` disables. |
| `strategy_breakeven_enabled` | `false` | `true/false` | Optional P3 breakeven test after +1R. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index CFD proxy from the card's primary P2 basket.
- `WS30.DWX` - Dow 30 index CFD proxy from the card's primary P2 basket.
- `GDAXI.DWX` - Matrix-valid DAX proxy for the card's GER40 basket member.
- `XAUUSD.DWX` - Gold proxy from the card's primary P2 basket.
- `EURUSD.DWX` - Major FX pair from the card's primary P2 basket.
- `GBPUSD.DWX` - Major FX pair from the card's primary P2 basket.

**Explicitly NOT for:**
- `GER40.DWX` - Card wording names GER40, but this symbol is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is registered instead.
- `SP500.DWX` - Card marks it optional/backtest-only rather than part of the primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `160` |
| Typical hold time | Intraday, minutes to hours; not specified as a frontmatter field. |
| Expected drawdown profile | Mixed intraday strategy with overfit and volume-proxy risk from three submodels. |
| Regime preference | Mean-reversion, momentum-breakout, and opening-range-breakout regimes. |
| Win rate target (qualitative) | Medium; not specified as a frontmatter field. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy`
**Pointer:** `https://www.tradingview.com/script/D94ChhXj-Reversal-Breakout-Strategy-with-ORB/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10750_tv-rev-brk-orb.md`

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
| v1 | 2026-06-14 | Initial build from card | de6f6fc6-4883-4e51-95c6-2b65e2494a8c |
