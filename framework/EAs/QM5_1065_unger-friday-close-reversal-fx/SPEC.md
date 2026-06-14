# QM5_1065_unger-friday-close-reversal-fx - Strategy Spec

**EA ID:** QM5_1065
**Slug:** unger-friday-close-reversal-fx
**Source:** eb97a148-0af9-5b9c-878c-25fb5dfa34f9
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA evaluates the most recent closed Friday D1 bar against the high-low range of the prior five D1 trading bars, including that Friday bar. If Friday closed in the top decile of that range, the EA sells at the next broker Sunday/Monday reopen window; if Friday closed in the bottom decile, it buys. The take profit is the fixed midpoint of the five-day range and the stop loss is `SL_ATR` times ATR(20, D1). Open trades are otherwise left to the broker SL/TP and the framework Friday-close time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_lookback_days` | 5 | 3-20 | Number of closed D1 bars used for the Friday range. |
| `strategy_decile_threshold` | 0.10 | 0.01-0.49 | Fraction of the range defining top and bottom extreme zones. |
| `strategy_atr_period` | 20 | 1+ | ATR period on D1 for the hard stop. |
| `strategy_sl_atr_mult` | 2.0 | 0+ | ATR multiplier for the hard stop distance. |
| `strategy_sunday_reopen_hour` | 21 | 0-23 | Earliest broker Sunday hour allowed for reopen entries. |
| `strategy_monday_entry_end_h` | 6 | 0-23 | Latest broker Monday hour allowed for the reopen entry. |
| `strategy_spread_mult` | 3.0 | 0+ | Maximum current spread as a multiple of median D1 spread. |
| `strategy_spread_lookback_days` | 20 | 1-60 | Closed D1 bars used for the median spread estimate. |
| `strategy_skip_holiday_week` | true | true/false | Skip Christmas and New-Year weeks. |
| `strategy_news_filter_enabled` | true | true/false | Enable the strategy high-impact news blackout hook. |
| `strategy_news_blackout_min` | 240 | 0+ | Minutes before and after high-impact events to suppress Monday-open entries. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-stated FX major with DWX live-tradable history.
- `GBPUSD.DWX` - Card-stated FX major with DWX live-tradable history.

**Explicitly NOT for:**
- Equity indices and commodities - the source edge is a weekend FX reversal pattern, not an index or commodity carry pattern.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | D1 range and ATR only |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | One trading week maximum |
| Expected drawdown profile | Wider D1 ATR stop with weekly turnover. |
| Regime preference | Mean-revert / weekend-pattern |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** eb97a148-0af9-5b9c-878c-25fb5dfa34f9
**Source type:** book / podcast
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1065_unger-friday-close-reversal-fx.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1065_unger-friday-close-reversal-fx.md`

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
| v1 | 2026-06-14 | Initial build from card | 1056143d-1a11-4ffc-b3ea-80193d168a32 |
