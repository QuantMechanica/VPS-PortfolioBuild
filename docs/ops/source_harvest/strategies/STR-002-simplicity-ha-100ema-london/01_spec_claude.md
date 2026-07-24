# STR-002 — Claude independent spec (pre-reconciliation)

Source: thread 1010582 "Simplicity" (zeiman), complete 12 posts. Exec TF H1.
Symbols (source-listed): EURUSD, GBPUSD, USDCHF, USDJPY (.DWX).

## Core rules (verbatim mechanics)

1. **Trend gate:** price above 100-EMA (H1, close) → longs only; below → shorts
   only. Read at shift 1.
2. **Session:** signals only from 06:00 GMT for 9 hours (source "8-9 hours" →
   take 9, input). Entry-gating only; management runs around the clock.
   Mechanize GMT via broker-offset input? NO invented DST models (hard rule) —
   use `TimeGMT()` in tester/live (tester models GMT correctly) and compare
   against input `strategy_session_start_gmt=6`, `strategy_session_hours=9`.
3. **Signal:** on a new closed H1 bar: HA colour flip — above EMA: HA(2) red
   AND HA(1) green → BUY; below EMA: HA(2) green AND HA(1) red → SELL. (No
   pullback-length requirement in source — a single flip suffices.)
4. **Orders:** source opens 3 equal orders A/B/C: A and B with TP = 1R (SL
   distance), C with no TP, trailed. **Framework mechanization: ONE position
   with staged partial closes** — economically identical (close 1/3 at +1R,
   close 1/3 at +1R — i.e. 2/3 at the same level — trail the remaining 1/3):
   - Total risk of the package ≤1% rule: source risks 1% PER order (3% total
     initial risk). House cap is 1%/trade — **more restrictive wins**: total
     package risk = 1% (RISK_FIXED sizing on the whole position; the A/B/C
     economics are preserved by fractions, not absolute lots).
   - If the framework lacks partial-close helpers, fallback: full TP at 1R for
     2/3 is impossible → then variant "single position, TP=1R on half via
     server + trail" needs reconciliation with codex.
5. **SL:** below/above the *entry candle* — the SIGNAL candle (shift-1 HA bar):
   long SL = HA-low(1) (short: HA-high(1)); the visible HA candle is what the
   author placed stops around. Raw-candle variant (cfudge refinement) is
   documented, not built.
6. **TP (A/B tranches):** entry ± 1R where R = |entry − SL|.
7. **Trail (C tranche):** after A/B banked, on every new closed H1 bar move SL
   to HA-low(1) (long) / HA-high(1) (short); never widen; until hit.
8. No pyramiding: one package per symbol at a time; no re-entry while any
   position with our magic exists. New opposite signal does NOT force-close
   (exits are SL/TP/trail only).

## Inputs

```
input int    strategy_ema_period        = 100;
input int    strategy_session_start_gmt = 6;
input int    strategy_session_hours     = 9;
input double strategy_tranche_a_frac    = 0.3333; // closed at +1R
input double strategy_tranche_b_frac    = 0.3333; // closed at +1R (same level)
```

## Hooks sketch

- **NoTradeFilter:** invalid params; warmup < ema_period+5 H1 bars; outside
  session window (entry gating only — but skeleton calls filter before Manage;
  session must NOT block management → session check belongs in EntrySignal,
  NOT in NoTradeFilter).
- **EntrySignal:** new-bar gate; no own position; session check; trend gate;
  HA flip; SL from HA extreme; TP=0 (tranches managed in Hook 3).
- **Manage:** state from position volume: full → watch for +1R (bid/ask ≥
  entry+R) → partial-close A+B fractions at market when touched (server-side
  limit-TP impossible on fractions of one position); remainder → per new
  closed bar trail SL to HA extreme of last closed candle.
- **ExitSignal:** false. **NewsFilterHook:** framework default.

## Notes / risks

- +1R touch detection is intra-bar (per tick) — market partial close on touch
  approximates the source's server TP on orders A/B (slippage documented).
- HA recursion helper identical to STR-097's (seed ≥150 bars, shifts ≥1).
- Frequency estimate: HA flips in trend during London on 4 majors — very
  roughly 60–150 signals/yr/symbol. Well above floor.
- Overlap: QM5_9977 (ledger) — distinct: 9977 was plain HA flip w/o session
  window and w/o tranche MM (verify in reconciliation).
