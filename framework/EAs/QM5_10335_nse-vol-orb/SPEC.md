# QM5_10335_nse-vol-orb - Strategy Spec

**EA ID:** QM5_10335
**Slug:** nse-vol-orb
**Source:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9 (see `strategy-seeds/sources/fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA defines the opening range as the first fifteen minutes of the configured cash session. After the range is complete, it buys when a closed M5 bar finishes above the opening-range high, or sells when a closed M5 bar finishes below the opening-range low. The breakout bar must have tick volume at least 1.20 times the rolling twenty-session median for the same time of day, and the EA takes only the first valid breakout in each session. Positions exit after three M5 bars or at the configured cash-session close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_session_open_hour` | 9 | 0-23 | Broker-time hour for the cash-session open used to start the opening range. |
| `strategy_session_open_minute` | 0 | 0-59 | Broker-time minute for the cash-session open. |
| `strategy_session_close_hour` | 17 | 0-23 | Broker-time hour for the same-session close exit. |
| `strategy_session_close_minute` | 30 | 0-59 | Broker-time minute for the same-session close exit. |
| `strategy_opening_range_minutes` | 15 | 5-30 | Opening-range length from the card baseline. |
| `strategy_volume_median_sessions` | 20 | 1-60 | Prior sessions used for same-time-of-day median tick volume. |
| `strategy_relative_volume_min` | 1.20 | 1.00-5.00 | Minimum breakout-bar volume divided by same-time median volume. |
| `strategy_holding_bars` | 3 | 1-50 | M5 bars to hold before time-stop exit. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for the emergency stop cap. |
| `strategy_emergency_atr_mult` | 0.80 | 0.10-5.00 | Maximum stop distance from entry as an ATR multiple. |
| `strategy_spread_lookback_bars` | 120 | 20-500 | Closed bars used for rolling spread percentile. |
| `strategy_spread_percentile` | 80.0 | 50.0-99.0 | Spread percentile threshold above which entries are skipped. |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - canonical DAX custom symbol available in the DWX symbol matrix; used as the port for card-stated `GER40.DWX`.
- `NDX.DWX` - Nasdaq 100 index CFD with liquid intraday tick-volume data.
- `SP500.DWX` - canonical S&P 500 custom symbol for U.S. large-cap index ORB tests.
- `WS30.DWX` - Dow 30 index CFD with liquid intraday tick-volume data.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated name is not present in the DWX symbol matrix; `GDAXI.DWX` is registered instead.
- `SPX500.DWX` - not present in the DWX symbol matrix.
- `SPY.DWX` - not present in the DWX symbol matrix.

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
| Trades / year / symbol | `100` |
| Typical hold time | 3 M5 bars, or until same-session close if the time stop has not fired |
| Expected drawdown profile | Breakout losses bounded by the opposite opening-range side with a 0.80 ATR emergency cap |
| Regime preference | Intraday breakout / high relative-volume sessions |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
**Source type:** paper
**Pointer:** https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5198458
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10335_nse-vol-orb.md`

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
| v1 | 2026-06-13 | Initial build from card | 4c77bd25-dc01-4139-9b7d-1ddf2a733f5b |
