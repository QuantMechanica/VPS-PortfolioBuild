# QM5_10868_tv-atr-vol-rev - Strategy Spec

**EA ID:** QM5_10868
**Slug:** tv-atr-vol-rev
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA watches each closed bar for an exhaustion candle whose range is at least 2.0 times ATR(14), whose tick volume is at least 2.0 times the prior 20-bar average, and whose body is at least 40% of the full range. A bearish exhaustion bar that closes below the prior 20-bar range creates a long trigger on the next bar above the midpoint between that bar's high and close. A bullish exhaustion bar that closes above the prior 20-bar range creates a short trigger on the next bar below the midpoint between that bar's low and close. Stops sit beyond the exhaustion candle extreme by 0.25 ATR, targets use the nearer of the prior-range mean and 1.0R, and positions close after 12 bars if SL or TP has not fired.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_atr_period | 14 | 1+ | ATR lookback for exhaustion range and stop buffer. |
| strategy_atr_multiplier | 2.0 | 1.5-2.5 tested | Minimum candle range as a multiple of ATR. |
| strategy_volume_period | 20 | 1+ | Prior bars used for average tick volume. |
| strategy_volume_spike_mult | 2.0 | 1.5-2.5 tested | Minimum tick-volume spike versus the average. |
| strategy_range_lookback | 20 | 1+ | Prior bars used for recent upper/lower range and mean target. |
| strategy_body_min_pct | 0.40 | 0.0-1.0 | Minimum candle body share of total range. |
| strategy_atr_stop_buffer | 0.25 | 0.0+ | ATR buffer beyond the exhaustion candle extreme. |
| strategy_target_r | 1.0 | 0.8-1.3 tested | Fixed R target candidate. |
| strategy_time_exit_bars | 12 | 8-16 tested | Maximum hold in bars before strategy close. |
| strategy_cooldown_bars | 8 | 0+ | Bars to wait after a closing deal before a new entry. |
| strategy_max_spread_stop_pct | 0.12 | 0.0+ | Maximum spread as a share of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - FX major with DWX tick volume and liquid intraday bars.
- GBPUSD.DWX - FX major with DWX tick volume and liquid intraday bars.
- XAUUSD.DWX - Metal symbol included by the card for volatility exhaustion testing.
- NDX.DWX - Liquid index CFD included by the card for intraday index testing.
- GDAXI.DWX - Canonical DWX DAX symbol; used in place of card text `GER40.DWX`, which is not present in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- GER40.DWX - Card-stated alias not present in `dwx_symbol_matrix.csv`; replaced by GDAXI.DWX.
- SP500.DWX - Mentioned only as a possible later SP500 test caveat, not part of the R3 primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 primary; M5 and M30 setfiles also generated from card Parameters To Test |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | 8-16 bars, default 12 bars |
| Expected drawdown profile | Medium cadence contrarian volatility with risk from repeated trend-day exhaustion signals. |
| Regime preference | Mean-reversion after volatility exhaustion and volume spikes. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `ATR Exhaustion Volume Spike Strategy`, author `MyStrategyHub`, Apr 8, accessed 2026-05-22
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10868_tv-atr-vol-rev.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | 4e334676-e0b3-42a5-b6b7-82fb95ee6c0f |
