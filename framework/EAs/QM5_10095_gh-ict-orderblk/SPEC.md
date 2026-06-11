# QM5_10095_gh-ict-orderblk - Strategy Spec

**EA ID:** QM5_10095
**Slug:** `gh-ict-orderblk`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades H1 order-block reversals in the direction of the weekly open bias. A long setup requires price above the Monday H1 open, a bearish previous H1 candle whose body is more than 10 percent of its range, the previous close to be the lowest close in the shifted 24-bar window, price to trade back to the previous candle open, and SMA(5) to have stayed above SMA(30) for 24 bars. A short setup mirrors those rules below the weekly open with a bullish previous candle, the previous close as the highest close in the shifted window, and SMA(5) below SMA(30). Initial stops use the previous H1 low or high, take profit is 3R or 4R based on the five-day average daily body, and the stop moves to entry plus or minus 1R after price reaches 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_look_back` | 24 | 1+ bars | Shifted H1 close and SMA state lookback. |
| `strategy_order_block_threshold` | 10.0 | 0-100 | Minimum previous candle body as percent of H1 range. |
| `strategy_h1_range_adr_ratio` | 0.80 | 0+ | Blocks entries when the previous H1 range exceeds this fraction of average D1 body. |
| `strategy_daily_body_days` | 5 | 1+ days | D1 open-close body averaging window. |
| `strategy_fast_sma` | 5 | 1+ bars | Fast SMA period for trend-state filter. |
| `strategy_slow_sma` | 30 | 1+ bars | Slow SMA period for trend-state filter. |
| `strategy_rr_low_range` | 3.0 | 0+ | Reward multiple when average daily body is below the source threshold. |
| `strategy_rr_high_range` | 4.0 | 0+ | Reward multiple when average daily body is at or above the source threshold. |
| `strategy_high_range_threshold` | 10.0 | 0+ price units | Average daily body threshold that selects the 4R target. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target; major FX pair with H1 and D1 OHLC available in the DWX matrix.
- `XAUUSD.DWX` - card target; gold CFD with H1 and D1 OHLC available in the DWX matrix.
- `GDAXI.DWX` - canonical DWX DAX symbol used for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 average body over five closed daily bars |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Not specified in card frontmatter; bounded by SL, TP, 2R stop movement, and Friday close. |
| Expected drawdown profile | Not specified in card frontmatter. |
| Regime preference | Weekly-open-biased order-block reversal with SMA trend-state filter. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** GitHub repository
**Pointer:** `artifacts/cards_approved/QM5_10095_gh-ict-orderblk.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10095_gh-ict-orderblk.md`

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
| v1 | 2026-06-11 | Initial build from card | b8e40060-abf9-40ef-a91b-f2e64487ca89 |
