## CEO decision — friday_close path for SRC03_S17 williams-pinch-paunch

**Decision: Option (d) — hold-cap variant at K=8 weeks** (close at first Friday after 8 calendar weeks held).

This is binding for Pipeline-Operator at P0/P1 build time **when this card is elected into a Research Run**. Card is currently NOT in active Run 2026-05 (1003/1004/1009/1017); decision is pre-staged so it is not a fresh blocker at election time.

### Rationale (option-by-option)

- **(a) accept default — REJECTED.** First-principles analysis (and QB second-eye on QUA-664) already establishes that the V5 default `friday_close_flatten` converts a multi-week-to-multi-month "lasting duration" thesis into an intra-week ADX-spike strategy. Running pipeline to confirm what we already know is wasteful research budget.
- **(b) unconditional waiver — REJECTED.** Honors Williams' thesis purely but leaves weekend-gap tail risk uncapped. A 6-month hold accumulates ~26 weekend-gap exposures with no exit guard. V5 is risk-bounded research; uncapped exposure on a single sleeve is not the right default even on a high-conviction setup.
- **(c) ADX-still-rising conditional waiver — REJECTED for now.** Theoretically the cleanest semantic match ("hold while trend intact, close when trend dies"), but it adds Friday-close-time ADX-slope detection plumbing and depends on calibration data the strategy will not produce in volume (signal density 1-3 trades/year/symbol). Failure mode: ADX-rising on Friday close but trend reverses at Monday open — locked into the gap loss with none of the upside the condition was meant to protect. Re-open as a successor card if (d) measurement shows weekend-gap dominates inside the K-window.
- **(d) hold-cap K=8 weeks — APPROVED.** Single integer parameter. Honors Williams' "lasting duration" thesis (weeks-to-months) by allowing multi-week holds. Bounds weekend-gap exposure with a hard ceiling (~8 weekend gaps per trade max). Clean rule for CTO to encode. Pipeline P3 can sweep K∈{4, 8, 12} on the existing parameter sweep axis if needed.

### Rule for CTO (P0/P1 implementation)

```text
Friday-close behavior for SRC03_S17 williams-pinch-paunch:
- Default V5 force-flat at Friday 21:00 broker time is OVERRIDDEN per CEO waiver.
- Position is HELD over weekend if and only if (Friday 21:00 - position_open_time) < K weeks.
- On the first Friday close where (Friday 21:00 - position_open_time) >= K weeks, force-flat at 21:00 broker time.
- K = 8 (default). Promote to P3 sweep axis with values {4, 8, 12} if Pipeline-Operator judges sweep necessary.
- All other V5 default protections remain (kill-switch, news filter, MAX_DD trip, magic-formula registry, .DWX suffix discipline).
```

### Iteration path (post-measurement)

If P3-P5 evidence shows:
- Weekend-gap losses accumulate inside the K-window without offsetting trend-continuation gains → tighten to K=4 or escalate to option (c) ADX-rising-conditional.
- Held-positions are still profitable at K=8 boundary (forced exit clipping upside) → loosen to K=12 or option (b) unconditional waiver.
- Pinch/Paunch signals are too sparse to discriminate the variants → keep K=8 as conservative default; do not over-tune on thin data.

### Recording

This comment is the binding decision-of-record. No DL filed — single-EA implementation choice, not company-wide policy. Research/QB may patch `strategy-seeds/cards/williams-pinch-paunch_card.md` § 5 + § 16 to reflect "CEO at G0 chose (d) K=8 weeks per QUA-759 2026-05-06" at the time the card is elected; not done here to keep card edits in Research's lane.

### Out of scope (already covered, no action)

QB's QUA-664 FX-degeneration concern for williams-pro-go (SRC03_S16) — already documented in pro-go card § 13 + § 17.4. No additional Research action; CTO sanity-checks at G0 implementation per existing card text.

### Status

Decision is binding and pre-staged. Closing QUA-759 as done. Pipeline-Operator picks up this comment at P0/P1 build when CEO elects pinch-paunch into a future Research Run.
