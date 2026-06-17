# QM5_10972_ftmo-trap-rev - Strategy Spec

**EA ID:** QM5_10972
**Slug:** `ftmo-trap-rev`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades H1 false breaks of a 40-bar support or resistance range. For a short, a candle must pierce above resistance by at least 0.25 ATR and then a later H1 candle within three bars must close back below resistance in its lower 40% with RSI confirmation. For a long, the mirrored rule pierces below support, then closes back above support in the upper 40% with RSI confirmation. Stops sit beyond the trap extreme by 0.30 ATR; targets use the opposite side of the range or 2.0R, whichever is closer, with breakeven after 1.0R and a 24-bar time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_level_lookback` | 40 | 5-200 | Bars used to define support and resistance. |
| `strategy_test_lookback` | 80 | 40-300 | Bars checked for prior level tests. |
| `strategy_min_level_tests` | 2 | 1-10 | Minimum touches required before a trap is valid. |
| `strategy_reclaim_bars` | 3 | 1-10 | Maximum H1 bars allowed from trap pierce to reclaim close. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for pierce, stop, and range filters. |
| `strategy_pierce_atr_mult` | 0.25 | 0.01-2.0 | ATR fraction required for the false break pierce. |
| `strategy_sl_atr_buffer` | 0.30 | 0.01-5.0 | ATR buffer beyond the trap high or low for SL. |
| `strategy_take_rr` | 2.0 | 0.5-10.0 | RR target candidate compared with the opposite range side. |
| `strategy_breakeven_rr` | 1.0 | 0.5-5.0 | R multiple that triggers SL move to breakeven. |
| `strategy_time_exit_bars` | 24 | 1-240 | Maximum holding period in H1 bars. |
| `strategy_max_trap_range_atr` | 2.5 | 0.5-10.0 | Blocks oversized trap candles. |
| `strategy_min_range_height_atr` | 1.5 | 0.1-10.0 | Blocks compressed ranges. |
| `strategy_rsi_period` | 14 | 2-100 | RSI period for reclaim confirmation. |
| `strategy_rsi_short_min` | 55.0 | 0-100 | RSI threshold allowing short reclaim. |
| `strategy_rsi_short_fall_from` | 70.0 | 0-100 | Prior RSI level for falling-from-overbought short confirmation. |
| `strategy_rsi_long_max` | 45.0 | 0-100 | RSI threshold allowing long reclaim. |
| `strategy_rsi_long_rise_from` | 30.0 | 0-100 | Prior RSI level for rising-from-oversold long confirmation. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-approved liquid major FX pair for H1 false-break testing.
- `GBPUSD.DWX` - card-approved liquid major FX pair with sufficient DWX H1 history.
- `XAUUSD.DWX` - card-approved liquid metal symbol for support/resistance traps.
- `NDX.DWX` - card-approved liquid US index symbol for H1 false-break testing.

**Explicitly NOT for:**
- `SPX500.DWX` - not a canonical DWX matrix symbol.
- `SPY.DWX` - not a canonical DWX matrix symbol.
- `ES.DWX` - not a canonical DWX matrix symbol.

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
| Trades / year / symbol | `38` |
| Typical hold time | `intraday to 24 H1 bars` |
| Expected drawdown profile | `moderate reversal drawdown; losses limited by trap-extreme ATR stop` |
| Regime preference | `mean-revert / false-break reversal` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `FTMO blog`
**Pointer:** `https://ftmo.com/en/blog/dont-get-caught-in-the-trap/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10972_ftmo-trap-rev.md`

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
| v1 | 2026-06-18 | Initial build from card | 43a84ce4-5148-454c-b18a-33f219ead710 |
