# STR-103 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_three-little-pigs-mtf-sma` · exec TF: H4 · Symbols (slots 0–7):
AUDUSD, EURGBP, EURJPY, EURUSD, GBPUSD, USDCAD, USDCHF, USDJPY (.DWX).
Base: `EA_Skeleton.mq5`; only hooks + inputs below are strategy code.

## Inputs

```
input int    strategy_sma_w1          = 55;
input int    strategy_sma_d1          = 21;
input int    strategy_sma_h4          = 34;
input int    strategy_atr_period      = 14;
input int    strategy_atr_lookback    = 30;    // Highest/Lowest ATR window (in-thread precedent, post #70)
input double strategy_atr_offset_fact = 0.25;  // 0.25 * (ATRhigh + ATRlow) -> offset pips
input double strategy_max_sl_pips     = 100.0; // post #40 cap, restrictive-global
```

## State / handles

- `g_h_sma_w1` (iMA W1 55 CLOSE), `g_h_sma_d1` (iMA D1 21 CLOSE),
  `g_h_sma_h4` (iMA H4 34 CLOSE), `g_h_atr` (iATR H4 14).
- Helper `OffsetPips()`: copy ATR buffer shifts 1..lookback; offset_price =
  `strategy_atr_offset_fact * (max+min)`; convert to pips via framework pip
  helper; returns pips (double). Fails → return −1 (callers skip action + log
  `SETUP_DATA_MISSING`).
- New-bar guard on H4 (`g_last_bar_time`). All indicator reads shift ≥1 on the
  respective TF (W1/D1 shift 1 = last CLOSED weekly/daily bar).
- No staged-entry state (dropped per reconciliation #1). Restart-safe: everything
  derives from closed bars + live position.

## Hook 1 — `Strategy_NoTradeFilter()`

Block when: any handle invalid; warmup insufficient (≥60 closed W1 bars, ≥30 D1,
≥`max(34, atr_lookback+atr_period)+5` H4); `OffsetPips()<=0`. Else allow.

## Hook 2 — `Strategy_EntrySignal(direction&)`

On new H4 bar only; no position/pending for this magic. LONG iff:
1. `CloseH4[1] > SMA55_W1[1]` AND `CloseH4[1] > SMA21_D1[1]`
   (W1/D1 SMA at their own shift 1; compared against the H4 trigger close)
2. `LowH4[1] <= SMA34_H4[1] && CloseH4[1] > SMA34_H4[1]` (touch-and-close)
SHORT mirror. Signal → framework market order at next-bar open.
SL at order time: `sl_price = SMA34_H4[1] − OffsetPips()` (long; mirror short);
then risk-distance cap: if `entry − sl_price > strategy_max_sl_pips` (pips) →
tighten SL to `entry − strategy_max_sl_pips`. Clamp to broker stops-level via
framework helper (widen to legal minimum only if below; log `VS_SL_UPDATE_FAIL`
class if clamp impossible). TP = 0 (open target).

## Hook 3 — `Strategy_ManageOpenPosition()`

On new H4 bar: candidate SL = `SMA34_H4[1] − OffsetPips()` (long; mirror short),
re-capped at `strategy_max_sl_pips` from CURRENT price is NOT applied (cap is
initial-risk only); ratchet: modify only if strictly better than current SL and
legal per stops-level. Never widen. No TP, no BE, no partials, no HA logic.
No forced exit on W1/D1 flip (reconciliation #7).

## Hook 4 — `Strategy_ExitSignal()`
False (server-side trailing SL is the exit).

## Hook 5 — `Strategy_NewsFilterHook()`
Framework default.

## Logging / errors

`STRATEGY_ENTRY` payload {dir, close, sma_w1, sma_d1, sma_h4, offset_pips,
sl, capped(bool)}; trail modifies logged via framework TM events; buffer-copy
failure → skip bar + `SETUP_DATA_MISSING` (once per bar).

## Compliance mapping

Standard Q01 checklist (magic/risk-mode/cap/news/daily-loss/ext-DD/Friday-close);
Friday-close deviation from source weekend-holds documented in card.
Frequency est. 12–35/yr/symbol.
