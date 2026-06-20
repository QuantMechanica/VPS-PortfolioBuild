# QM5_9982_bandy-h1-setup-m15-trigger-mr-index - Strategy Spec

**EA ID:** QM5_9982
**Slug:** bandy-h1-setup-m15-trigger-mr-index
**Source:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016 (see `strategy-seeds/sources/9ef19e06-5ca6-5b35-aa06-b8187aa0e016/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades a long-only index mean-reversion setup on M15. On each closed M15 bar it checks whether the most recent closed H1 bar has RSI(4) at or below 30 while H1 close remains above SMA(100), then requires the closed M15 RSI(2) to be at or below 10. A valid signal enters long at market on the first tick of the next M15 bar with a catastrophic stop 2.5 x M15 ATR(14) below entry.

The position closes when M15 RSI(2) reaches 70 or higher, when the H1 close falls back below the H1 SMA(100), or when the trade has been open for 32 M15 bars. The strategy has no short side, no scale-in, no partial close, no break-even move, and no trailing stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_h1_rsi_period` | 4 | 2-20 | H1 RSI setup period. |
| `strategy_h1_rsi_oversold` | 30.0 | 1-50 | Maximum H1 RSI value allowed for long setup. |
| `strategy_h1_sma_period` | 100 | 2-300 | H1 SMA period used for bullish regime filter. |
| `strategy_m15_rsi_period` | 2 | 2-20 | M15 RSI trigger and exit period. |
| `strategy_m15_rsi_entry_threshold` | 10.0 | 1-30 | Maximum M15 RSI value allowed for long trigger. |
| `strategy_m15_rsi_exit_threshold` | 70.0 | 50-99 | M15 RSI value that triggers strategy exit. |
| `strategy_atr_period_m15` | 14 | 2-100 | M15 ATR period for catastrophic stop distance. |
| `strategy_atr_sl_mult` | 2.5 | 0.5-10.0 | ATR multiple placed below long entry as SL. |
| `strategy_time_stop_m15_bars` | 32 | 1-200 | Maximum holding time in M15 bars. |
| `strategy_skip_first_session_m15` | true | true/false | Blocks triggers from the first M15 bar after configured broker session start. |
| `strategy_session_start_hour_broker` | 1 | 0-23 | Broker-hour anchor for the first-M15-bar skip. |
| `strategy_session_start_minute_broker` | 0 | 0-59 | Broker-minute anchor for the first-M15-bar skip. |
| `strategy_max_spread_points` | 0.0 | 0-disabled or positive | Optional wide-spread guard; zero modeled spread never blocks. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - card primary S&P 500 backtest index target; backtest-only custom symbol.
- `NDX.DWX` - card-approved live-routable US large-cap technology index proxy.
- `WS30.DWX` - card-approved live-routable US large-cap Dow index proxy.

**Explicitly NOT for:**
- Forex pairs - the card specifies an index mean-reversion substrate.
- Commodities and metals - not part of the card's R3 index universe.
- Non-DWX S&P variants such as `SPX500.DWX`, `SPY.DWX`, or `ES.DWX` - not canonical symbols in `dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | H1 RSI(4), H1 SMA(100), H1 close |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 130 |
| Typical hold time | Intraday, capped at 32 M15 bars (about 8 hours) |
| Expected drawdown profile | Mean-reversion index drawdowns bounded by 2.5 x M15 ATR catastrophic SL |
| Regime preference | Bullish-regime mean reversion after intraday pullbacks |
| Win rate target (qualitative) | Medium to high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
**Source type:** book
**Pointer:** Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 978-0-9791037-7-1, URL: https://books.google.com/books?isbn=9780979103771
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9982_bandy-h1-setup-m15-trigger-mr-index.md`

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
| v1 | 2026-06-20 | Initial build from card | f9931a12-5208-4f78-90ec-02fd97ef0c2c |
