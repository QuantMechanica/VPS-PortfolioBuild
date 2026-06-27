# QM5_10184_tv-atr-zigzag-break - Strategy Spec

**EA ID:** QM5_10184
**Slug:** `tv-atr-zigzag-break`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-27

---

## 1. Strategy Logic

The EA tracks ATR-filtered swing highs and swing lows on the configured signal timeframe. A swing becomes official only after price reverses by `strategy_pivot_atr_mult * ATR(14)` from the current extreme, then the EA arms a stop entry at the confirmed pivot in the next breakout direction. Each pivot can trigger only once, opposite swing confirmation cancels stale pending orders, and exits are handled by the initial ATR stop, the risk-reward target, or an opposite armed level while a position is open.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | `PERIOD_M15` or `PERIOD_H1` | Timeframe used for ATR and structural pivot confirmation. |
| `strategy_atr_period` | `14` | `5-100` | ATR lookback for pivot threshold and stop distance. |
| `strategy_pivot_atr_mult` | `2.0` | `0.5-6.0` | ATR multiple required to confirm a swing reversal. |
| `strategy_sl_atr_mult` | `1.5` | `0.5-6.0` | ATR multiple used for the initial stop distance. |
| `strategy_rr_mult` | `1.5` | `0.5-5.0` | Reward-to-risk multiple for the initial take profit. |
| `strategy_max_spread_stop_fraction` | `0.15` | `0.01-1.0` | Maximum modeled spread as a fraction of stop distance. |
| `strategy_rollover_start_hhmm_utc` | `2155` | `0000-2359` | UTC start of the no-entry rollover window. |
| `strategy_rollover_end_hhmm_utc` | `2210` | `0000-2359` | UTC end of the no-entry rollover window. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - liquid index CFD that matches the source's index breakout use case.
- `XAUUSD.DWX` - gold CFD, included because the source references futures-style volatility breakouts.
- `XTIUSD.DWX` - crude oil CFD, adding energy exposure beyond the current index/metal concentration.
- `GDAXI.DWX` - DAX proxy replacing unavailable `GER40.DWX` while preserving index breakout structure.
- `EURUSD.DWX` - major FX pair included for cross-asset portability and liquidity.

**Explicitly NOT for:**
- `GER40.DWX` - not registered because `GDAXI.DWX` is the matrix-valid DAX proxy for this build.
- `MN1` symbols/timeframes - monthly bars are not part of the card and are not reliable in the DWX tester.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `strategy_signal_tf` can be set to `M15` or `H1`; generated Q02 setfiles use `H1` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday to multi-day, depending on stop or target hit after breakout. |
| Expected drawdown profile | Breakout strategy with clustered losses in choppy ranges and larger wins during volatility expansion. |
| Regime preference | Volatility-expansion / breakout |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** `AI`
**Pointer:** TradingView script `ATR ZigZag Breakout`, author handle `ReflexSignals`, cited in `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10184_tv-atr-zigzag-break.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10184_tv-atr-zigzag-break.md`

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
| v1 | 2026-06-27 | Initial build from card | cf4dafbe-0938-4172-b4cf-baf0123601b5 |
