# STR-016 — Claude independent spec (pre-reconciliation)

Source: thread 1299658 "Range Breakout System" (Knodlz, ~2024). Exec TF M15.
Symbol: **USDJPY.DWX only** — the source specifies rules ONLY for USDJPY;
GBPUSD/NAS100 are named but their "slightly different" rules never given
(building them = invention).

## Core rules (post #1, times in the author's server clock GMT+3 — his
## The5ers server; ≡ our NY-close broker clock in summer, 1h drift winter →
## mechanize as literal BROKER hours, documented)

1. **Range:** high/low of 01:00–06:00 broker time (M15 bars whose open ∈
   [01:00, 06:00)).
2. At range end (06:00): place BUY STOP at range high, SELL STOP at range
   low. SL of each = the opposite range border. No TP.
3. **Straddle semantics:** both pendings live simultaneously; when one
   fills, the other remains? Source silent — classic straddle deletes the
   opposite order OR keeps it as reversal. Author's July-11 anecdote ("lost
   the Buy Position and than made ~15R on the Sell") proves BOTH can fill
   sequentially → the opposite pending STAYS active after the first fill
   (mechanization: keep; it becomes a stop-and-reverse-ish second trade;
   still SL = opposite border, i.e. its SL = the other side).
4. **Order deletion:** untriggered pendings deleted at 13:00 broker (the
   author's literal "1pm GMT+3"; his "1.5h before NY open" gloss is
   internally inconsistent — take the explicit clock time; flag).
5. **Position close:** all open positions closed 20:00 broker.
6. **Trailing:** "trail our SL on Highs/Lows" — mechanization: per new
   closed M15 bar, long SL = max(SL, low of last closed bar); short SL =
   min(SL, high of last closed bar). Never widen. (Bar-extreme trail is the
   minimal deterministic reading; reconciliation decides vs swing-based.)
7. One straddle per day; no re-arm after deletion/close.

## Inputs

```
strategy_range_start_hhmm = 100
strategy_range_end_hhmm   = 600
strategy_order_delete_hhmm= 1300
strategy_flat_hhmm        = 2000
```

## Hooks sketch

- NoTradeFilter: M15; params; warmup ≥ 1 day M15.
- EntrySignal: at the first bar with open ≥ range end (once per day, own
  latch): compute range from closed bars in window; place BUY STOP (one
  request per EntrySignal call — framework places ONE order per call; the
  second pending placed on the next tick/call via a pending-phase state
  machine: state PLACE_BUY → PLACE_SELL → DONE).
- Manage: per tick: delete pendings at 13:00; flatten positions at 20:00
  (QM_TM_ClosePosition); per new closed M15 bar: trail per rule 6.
- ExitSignal: false. NewsFilterHook: framework default.

## Risks / notes

- Two simultaneous positions possible (buy filled + later sell filled while
  buy still open? No — buy SL = range low = sell entry; when sell triggers,
  buy is stopped at the same level → effectively sequential; document).
- Overlap QM5_9936 (prior asian-range build): differentiate in
  reconciliation (9936's variant + status check).
- News straddle risk: house news filter blocks ENTRY placement in windows;
  pendings placed before a window persist (framework behaviour; document).
- Frequency: ~250 straddles/yr → floor safe.
