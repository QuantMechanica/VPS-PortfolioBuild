# STR-009 — Claude independent spec (pre-reconciliation)

Source: thread 1182304, joyny's CADJPY post ("Here is the reverse setup —
price beats notable number level and continues trend direction"). Exec TF M5
(same M5-openings edit applies thread-wide).

## Core mechanic (breakout continuation — inverse of STR-008)

BUY when the previous N days' highs AND lows are all BELOW the level and
price reaches the level "from below" (upward breakout through the lattice
level after N days one-side) → continuation. SELL mirror.

## Source-fixed setup (single symbol)

| Symbol | NN | N days | TP % | SL % | Entry window |
|---|---|---|---|---|---|
| CADJPY | 88 | 41 | 1.0 | 0.75 | 14:00-22:00 "London+2h" (= broker time) |

All shared mechanizations identical to STR-008 (level lattice, M5-openings
touch semantics with the mirrored side, N-day one-side gate via broker D1
shift 1..N, percent-of-entry TP/SL, one position, window gates entry only,
broker-time session clock).

Touch semantics (long): level between open(1) and high(1) — price came UP
into the level from below (mirror of the fade's approach-from-above).

## Build shape

Separate EA (distinct ea_id/slug) sharing the code pattern with STR-008 but
with inverted gate/approach logic — NOT an input flag on the fade EA
(different mechanic = different EA per survivor-port purity; also keeps both
Q02 verdicts independent).

## Hooks sketch

Identical structure to STR-008 with mirrored conditions; defaults = CADJPY
row; single-symbol cohort (slot 0).

## Risks / notes

- Single symbol, 41-day lookback, author-optimized: expected frequency low
  (CADJPY entries in his live log are sparse) — Q02 floor risk real; if
  below floor, RETIRE per economics rule (built for falsification of the
  only distinct un-built mechanic in the family).
- Overlap QM5_10042 as for STR-008.
