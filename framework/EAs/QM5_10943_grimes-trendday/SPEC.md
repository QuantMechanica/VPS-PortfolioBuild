# QM5_10943_grimes-trendday - Strategy Spec

**EA ID:** QM5_10943
**Slug:** `grimes-trendday`
**Source:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c` (see `strategy-seeds/sources/fbfd7f6e-462a-55c8-9efa-9005a70c9f5c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades M15 breakouts after a compressed prior D1 bar on index CFDs. A valid setup requires the prior D1 range to be no more than 0.65 * ATR(20,D1), plus either an inside-day relationship against the day before it or two consecutive D1 bars whose ranges are no more than 0.75 * their ATR(20,D1). After the first four M15 bars from the cash-session open proxy, the EA buys when a closed M15 bar closes above both the first-hour high and prior D1 high, or sells when it closes below both the first-hour low and prior D1 low. The stop is outside the first-hour range by 0.15 * ATR(20,M15), target is 3R, the stop trails after 1.5R using the prior three M15 lows/highs, and the trade exits at session close or when a closed M15 bar returns inside the first-hour range.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period_d1` | 20 | `> 0` | ATR period used for D1 compression and opening-range height checks. |
| `strategy_atr_period_m15` | 20 | `> 0` | ATR period used for the stop buffer. |
| `strategy_prior_range_atr_mult` | 0.65 | `> 0` | Maximum prior D1 range as a multiple of ATR(20,D1). |
| `strategy_two_day_range_atr_mult` | 0.75 | `> 0` | Maximum range multiple for both of the last two D1 bars. |
| `strategy_opening_range_bars` | 4 | `4` | First-hour M15 bars used to build the opening range. |
| `strategy_session_open_hour_broker` | 16 | `0-23` | Broker-hour proxy for the cash/session open. |
| `strategy_session_open_minute_broker` | 30 | `0-59` | Broker-minute proxy for the cash/session open. |
| `strategy_session_close_hour_broker` | 22 | `0-23` | Broker-hour proxy for session-close flattening. |
| `strategy_session_close_minute_broker` | 45 | `0-59` | Broker-minute proxy for session-close flattening. |
| `strategy_max_open_range_d1_atr_mult` | 0.90 | `> 0` | Reject setup if the first-hour range exceeds this multiple of ATR(20,D1). |
| `strategy_stop_m15_atr_mult` | 0.15 | `> 0` | ATR(20,M15) buffer beyond the first-hour range for the initial stop. |
| `strategy_target_r_mult` | 3.00 | `> 0` | Take-profit distance as a multiple of initial risk. |
| `strategy_trail_trigger_r` | 1.50 | `> 0` | R multiple at which the prior-three-bar trailing stop activates. |
| `strategy_trail_lookback_bars` | 3 | `>= 1` | Closed M15 bars used for the trailing stop. |
| `strategy_spread_stop_fraction` | 0.10 | `> 0` | Skip entry if spread exceeds this fraction of stop distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index exposure explicitly named by the card; backtest-only per DWX discipline.
- `NDX.DWX` - Nasdaq 100 index exposure in the card's portable basket.
- `WS30.DWX` - Dow 30 index exposure in the card's portable basket.
- `GDAXI.DWX` - registered DAX 40 custom symbol used as the available DWX equivalent for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 variants; use `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `PERIOD_D1` for prior-day compression and prior-day high/low confirmation |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `12` |
| Typical hold time | Intraday, from first-hour breakout until 3R, prior-three-bar trailing stop, inside-range return, or session close. |
| Expected drawdown profile | Sparse breakout strategy with clustered false-break losses when compression fails to expand. |
| Regime preference | Volatility-compression to trend-day expansion / breakout. |
| Win rate target (qualitative) | Medium-low, offset by 3R target and trend-day tails. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`
**Source type:** blog
**Pointer:** Adam H. Grimes, "Finding trend days in index futures", 2015-09-16, https://www.adamhgrimes.com/finding-trend-days-in-index-futures/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10943_grimes-trendday.md`

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
| v1 | 2026-06-06 | Initial build from card | e4b2f7cd-5ab9-4dac-8c28-7d3a7ebce6d6 |
