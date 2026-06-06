# QM5_10921_grimes-bearflag - Strategy Spec

**EA ID:** QM5_10921
**Slug:** `grimes-bearflag`
**Source:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c` (see Adam H. Grimes blog citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades a daily momentum flag after a structural break. A short setup requires a close below a prior 20-bar close low, a lower Keltner Channel touch, and a MACD 60-bar low near the break, followed by a 2-8 bar shallow bounce that retraces no more than 50% of the impulse and then closes below the bounce low. Long setups mirror this after an upside break, upper Keltner touch, MACD 60-bar high, shallow pullback, and close above the pullback high. Stops sit beyond the bounce or pullback extreme plus 0.25 ATR(14), entries are rejected if the stop exceeds 3 ATR(14), and management either trails after a 1R daily close in the trade direction or exits when 1R is touched without that close confirmation.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_keltner_period` | 20 | 2+ | EMA and ATR period for the Keltner Channel. |
| `strategy_keltner_atr_mult` | 2.25 | >0 | ATR multiplier around EMA(20) for channel touch validation. |
| `strategy_breakout_lookback` | 20 | 2+ | Prior close window used as support/resistance proxy. |
| `strategy_breakdown_scan_bars` | 10 | 3+ | Maximum age of the impulse break from the trigger bar. |
| `strategy_macd_fast` | 12 | 1+ | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | greater than fast | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 1+ | MACD signal period. |
| `strategy_macd_extreme_lookback` | 60 | 2+ | Lookback for new MACD high/low confirmation. |
| `strategy_macd_extreme_window` | 3 | 1+ | Bars near the impulse break allowed for the MACD extreme. |
| `strategy_bounce_min_bars` | 2 | 1+ | Minimum bounce or pullback length after the impulse break. |
| `strategy_bounce_max_bars` | 8 | >= minimum | Maximum bounce or pullback length after the impulse break. |
| `strategy_bounce_max_retrace` | 0.50 | 0-1 | Maximum retracement for a valid reluctant bounce. |
| `strategy_bounce_reject_retrace` | 0.618 | >= max retrace | Explicit hard rejection level for deeper bounces. |
| `strategy_sl_atr_period` | 14 | 2+ | ATR period for stop buffer and trailing. |
| `strategy_sl_atr_buffer_mult` | 0.25 | >=0 | ATR buffer added beyond the bounce/pullback extreme. |
| `strategy_max_stop_atr_mult` | 3.0 | >0 | Rejects entries whose stop distance exceeds this ATR multiple. |
| `strategy_target_r_mult` | 1.0 | >0 | Initial R multiple used for target-touch management. |
| `strategy_trail_atr_mult` | 2.0 | >0 | ATR multiple for trailing after a confirmed 1R continuation close. |
| `strategy_time_exit_bars` | 10 | 1+ | Maximum D1 bars to hold a position. |
| `strategy_spread_stop_fraction` | 0.10 | >0 | Maximum spread as a fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major suitable for daily trend-continuation testing.
- `GBPUSD.DWX` - liquid FX major suitable for daily trend-continuation testing.
- `XAUUSD.DWX` - liquid metal contract with daily momentum impulses.
- `XTIUSD.DWX` - liquid oil contract with daily momentum impulses.
- `GDAXI.DWX` - DAX index custom symbol used as the available DWX equivalent for the card's `GER40.DWX` leg.

**Explicitly NOT for:**
- `GER40.DWX` - named in the card but absent from `dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- Symbols outside `dwx_symbol_matrix.csv` - not registered for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `12` |
| Typical hold time | `up to 10 D1 bars` |
| Expected drawdown profile | `trend-continuation losses should be bounded by one initial ATR-structure stop per position` |
| Regime preference | `trend-continuation / breakout after shallow flag retracement` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`
**Source type:** `blog`
**Pointer:** Adam H. Grimes, "A bear flag in Treasuries: a good setup and a clean trade" and "Bear flags in cryptos"; see `artifacts/cards_approved/QM5_10921_grimes-bearflag.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10921_grimes-bearflag.md`

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
| v1 | 2026-06-06 | Initial build from card | be29e6d7-1dec-4384-85fc-7eaf113cdb74 |
