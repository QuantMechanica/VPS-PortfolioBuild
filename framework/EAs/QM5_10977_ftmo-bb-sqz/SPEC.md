# QM5_10977_ftmo-bb-sqz — Strategy Spec

**EA ID:** QM5_10977
**Slug:** `ftmo-bb-sqz`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

This EA trades a Bollinger Band squeeze-breakout on closed H1 bars, long and
short. It builds Bollinger Bands with SMA(20) and 2.0 standard deviations and
measures band width (upper minus lower). A "squeeze" exists when the current
band width sits in the lowest 20th percentile of the previous 120 bars'
widths. When a squeeze occurred within the last 6 bars and the bar then closes
above the upper band while also above the SMA(20), the EA enters long at market;
the mirror condition (close below the lower band and below SMA(20)) enters
short. Over-extended breakout bars whose range exceeds 2.5x ATR(14) are skipped.

The stop is placed just beyond the opposite band (long: lower band minus 0.25x
ATR; short: upper band plus 0.25x ATR). Take-profit is 2.5R from entry. Once
price travels 1.2R in favour, the stop is moved to breakeven. The position is
also closed if a later bar closes back across SMA(20) against the trade, or
after 36 closed H1 bars have elapsed (time stop).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 10-50 | Bollinger period (SMA + bands) |
| `strategy_bb_deviation` | 2.0 | 1.0-3.0 | Bollinger standard-deviation multiple |
| `strategy_sqz_lookback` | 120 | 60-240 | Squeeze percentile window in bars |
| `strategy_sqz_pct` | 20.0 | 10.0-40.0 | Squeeze percentile threshold (%) |
| `strategy_sqz_recent` | 6 | 1-20 | Squeeze armed if true within N recent bars |
| `strategy_atr_period` | 14 | 7-28 | ATR period (range filter + stop buffer) |
| `strategy_range_atr_mult` | 2.5 | 1.5-4.0 | Skip breakout bar if range > mult x ATR |
| `strategy_stop_atr_buffer_mult` | 0.25 | 0.0-1.0 | Stop buffer beyond opposite band, in ATR |
| `strategy_tp_rr` | 2.5 | 1.0-5.0 | Take-profit R-multiple |
| `strategy_be_trigger_rr` | 1.2 | 0.5-2.5 | Move SL to breakeven after this many R |
| `strategy_time_exit_bars` | 36 | 12-120 | Force-close after N closed H1 bars |
| `strategy_spread_pct_of_stop` | 15.0 | 5.0-50.0 | Skip if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX, clean volatility-cycle squeeze/expansion behaviour.
- `GBPUSD.DWX` — liquid major FX with frequent volatility expansions.
- `USDJPY.DWX` — liquid major FX; squeeze breakouts around session transitions.
- `XAUUSD.DWX` — high-volatility metal where band-squeeze expansions are pronounced.

**Explicitly NOT for:**
- Index CFDs (`NDX.DWX`, `WS30.DWX`, `SP500.DWX`) — card targets the FX/metals basket only; index gap/session dynamics are not what this card was calibrated on.

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
| Trades / year / symbol | `36` (card estimate 24-48) |
| Typical hold time | `hours to a few days (<= 36 H1 bars)` |
| Expected drawdown profile | `breakout strategy — clustered small losses on failed breakouts, occasional large 2.5R wins` |
| Regime preference | `volatility-expansion / breakout` |
| Win rate target (qualitative) | `low` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `forum` (FTMO educational blog article)
**Pointer:** https://ftmo.com/en/blog/technical-analysis-bollinger-bands-as-a-combination-of-trend-and-volatility/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10977_ftmo-bb-sqz.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor build |
