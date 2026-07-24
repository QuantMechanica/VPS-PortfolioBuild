# STR-003 — Claude independent spec (pre-reconciliation)

Source: thread 1075281 "Previous Day Breakout Edge" (Proc), complete 60 posts.
Exec TF H1. Symbols (author-backtested): EURUSD, GBPUSD (.DWX).

## Core rules

1. **Trading-day anchor:** author separates days at 22:00 GMT ("trading day
   starts at 10 PM GMT"). Broker is NY-close GMT+2/+3 → broker D1 midnight =
   22:00 GMT (winter) / 21:00 GMT (summer). **Mechanize with broker D1 bars**
   (`iHigh/iLow(_Symbol, PERIOD_D1, 1)`) — matches the author's day exactly in
   winter, 1h off in summer; no invented DST arithmetic (hard rule), and the
   NY-close day is the house convention. Documented deviation.
2. **Signal (long):** an H1 bar CLOSES above previous day's high (close, not
   wick). Short: H1 close below previous day's low.
   **First qualifying close per level per trading day only** ("any subsequent
   candles close after that ... is irrelevant"). Both directions may fire the
   same day (independent levels). One trade per level per day.
3. **Filter (author-used, input default ON):** SMA(34) on H1 close — long only
   if signal close > SMA34(1); short only if < . Input to disable.
4. **Entry:** market at the OPEN of the next H1 bar (i.e., when the new bar
   arrives and the previous bar qualified → enter immediately; skeleton's
   closed-bar EntrySignal does exactly this).
5. **SL/TP fixed:** SL 12.5 pips, TP 25 pips (1:2). Inputs; per-symbol
   overrides via set files only if source-backed (they are not — keep uniform).
6. **No re-entry** on the same level same day after SL/TP (source: rinse and
   repeat = next opportunity/level, not martingale). No scaling (author
   mentions optional scale-ins — NOT built; documented variant).
7. **No session filter** in core rules (author's London preference is
   discretionary; Maddin's 06:00–17:00 GMT-1 was a tester variant). Not built.
8. One position per symbol at a time (if a long is open and the short level
   confirms, skip — conservative, no hedging; framework single-magic).

## Inputs

```
input int    strategy_sma_period    = 34;
input bool   strategy_sma_filter    = true;
input double strategy_sl_pips       = 12.5;
input double strategy_tp_pips       = 25.0;
```

## State

- `g_day_key` (prev-D1 bar time) → resets `g_long_done` / `g_short_done`
  flags on new trading day. Restart-safe: flags rebuild by scanning today's
  closed H1 bars for a prior qualifying close (replay, deterministic).
- Prev-day high/low from D1 shift 1 each new D1 bar.

## Hooks sketch

- **NoTradeFilter:** params sane; ≥2 closed D1 bars; ≥ sma_period+5 H1 bars;
  handles valid (single iMA H1 SMA34).
- **EntrySignal:** new H1 bar; no own position; day-flags; qualifying close on
  bar shift 1 vs prev-day level (level from D1 shift 1 **as of that bar** —
  use the D1 level captured at day start, not recomputed intraday);
  SMA filter; set direction; SL/TP fixed pips via `QM_StopFixedPips`/
  `QM_TakeFixedPips` equivalents; mark day-flag done.
- **Manage:** nothing (server-side SL/TP only). **ExitSignal:** false.
- **NewsFilterHook:** framework default (author's fundamentals caution =
  discretionary; house news filter covers it).

## Notes / risks

- 12.5-pip SL on GBPUSD spikes → stops-level clamp path needed.
- Frequency: EURUSD confirmed breaks ~2-4/week → ~100-200 signals/yr before
  filter; well above floor.
- Overlap QM5_10007 (prior prev-day-breakout family build): distinguish in
  reconciliation — 10007 used stop orders at the level (no close confirmation)
  and ATR-based exits (verify from its SPEC); this build is the
  close-confirmed, fixed-pips, next-open-entry variant.
- Thread contains a NEGATIVE systematic test (Maddin −3R over 13 months on the
  unfiltered rule set) — recorded for honesty; Q02+ judges.
