# QM5_10920_grimes-ib-break - Strategy Spec

**EA ID:** QM5_10920
**Slug:** grimes-ib-break
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades D1 inside-bar breakouts. A setup exists when the last closed bar is inside the prior bar, or when two recent inside bars sit inside the same mother bar, and the context is either a large mother bar or an inside close near a 20-bar high or low. The EA places one directional stop order beyond the inside-bar high or low with a 0.05 ATR buffer, uses the opposite side plus the same ATR buffer as the stop, takes profit at 1.0R, and exits any filled trade after three D1 bars if TP/SL has not closed it.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | >=1 | ATR period for context, buffers, and stop-distance validation. |
| `strategy_mother_atr_min_mult` | 1.25 | >0 | Mother bar must be at least this many ATRs to qualify as large-bar context. |
| `strategy_level_lookback_bars` | 20 | >=2 | Lookback for the critical high/low proximity test. |
| `strategy_level_atr_near_mult` | 0.35 | >=0 | ATR distance from the 20-bar high/low that qualifies as near a critical level. |
| `strategy_entry_buffer_atr_mult` | 0.05 | >=0 | ATR buffer added to stop-entry and stop-loss levels. |
| `strategy_min_stop_atr_mult` | 0.35 | >0 | Minimum stop distance as a multiple of ATR. |
| `strategy_max_stop_atr_mult` | 2.50 | > minimum | Maximum stop distance as a multiple of ATR. |
| `strategy_min_inside_mother_frac` | 0.25 | >=0 | Rejects inside bars whose range is less than this fraction of the mother bar. |
| `strategy_spread_stop_frac` | 0.10 | >0 | Maximum spread as a fraction of stop distance. |
| `strategy_target_r_mult` | 1.00 | >0 | Profit target in R. |
| `strategy_pending_expiry_bars` | 2 | >=1 | Pending stop expiry in D1 bars. |
| `strategy_time_exit_bars` | 3 | >=1 | Filled-position time exit in D1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 large-cap index exposure from the card basket; backtest-only per matrix note.
- `NDX.DWX` - Nasdaq 100 large-cap index exposure from the card basket.
- `GDAXI.DWX` - DAX index proxy for the card's `GER40.DWX`, which is not present in the DWX matrix.
- `XAUUSD.DWX` - Gold metal exposure from the card basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 variants; `SP500.DWX` is the canonical custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 18 |
| Typical hold time | Up to 3 D1 bars after entry; pending entry expires after 2 D1 bars. |
| Expected drawdown profile | Breakout losses should be bounded by the opposite-side inside-bar stop. |
| Regime preference | Breakout / volatility expansion after inside-bar compression. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, "The power of an inside bar", 2020-10-28, https://www.adamhgrimes.com/the-power-of-an-inside-bar/; supplemental TradeLab article, 2018-11-07, https://adamhgrimes.com/tradelab-reviewing-some-recent-trades-we-published/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10920_grimes-ib-break.md`

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
| v1 | 2026-06-06 | Initial build from card | 687f75b4-61b8-45da-9314-dc979f3e19f1 |
