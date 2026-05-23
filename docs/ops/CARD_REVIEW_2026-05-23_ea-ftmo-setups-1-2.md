# Card Review — EA FTMO Set-Up 1 & 2
Date: 2026-05-23
Reviewer: Claude
Tasks: 47059b7b (Set Up 1), 84931317 (Set Up 2)
Verdict: RECYCLE (both)

---

## Set Up 1 — Catch A Quick Move (ea_id 10901)

**Verdict: RECYCLE**

### What works
- Structural cause is legitimate: London open (08:00 GMT) creates a genuine
  liquidity event. Institutional flow, spread compression, and momentum
  establishment are real phenomena. The "session open breakout" edge class
  has historical precedent.
- News blackout correctly included.
- FTMO DD constraints stated.

### Fatal defects
1. **Multi-pair real-time currency strength meter**: The entry signal requires
   a composite currency strength computation across G10 pairs at bar-open.
   MT5's strategy tester is single-instrument; there is no mechanism for
   cross-pair real-time data aggregation during a backtest. This design is
   unimplementable in the V5 pipeline. The card must be reformulated to use
   only single-pair price action.

2. **M1 timeframe = known infra blocker**: M1 history for DWX symbols only
   covers from approx. 2022+; the Q02 enqueue creates 0 work_items for M1
   EAs against the required 2017-present window. The card must lift to M5
   or higher.

3. **"20% divergence gap" is undefined**: No denominator, no normalisation
   method, no reference range. Cannot be implemented without arbitrarily
   choosing a scale.

### Rework requirements for re-submission
- Replace currency strength signal with single-pair price-action signal at
  the London open candle (e.g., first completed M5 candle breakout above /
  below the 30-minute pre-open range). All data must be self-contained in
  the single instrument's OHLCV.
- Lift timeframe to M5 minimum.
- Define SL and TP in pips or ATR multiples — not as session range anchors
  that depend on the strength signal.
- Remove or replace the "Currency Strength Meter" note with a concrete M5
  candle-structure rule.
- Re-estimate expected_trades_per_year given the single-entry-per-day
  constraint (~250 trading days × entry rate).

---

## Set Up 2 — Fibs Retracements (ea_id 10902)

**Verdict: RECYCLE**

### What works
- London session direction bias (D1 trend filter) is structurally sensible.
- News blackout correctly included.
- 1:3 R:R target is reasonable.
- FTMO DD constraints stated.

### Fatal defects
1. **No structural persistence argument**: "61.8% is the golden ratio" is not
   a persistence mechanism. Fibonacci levels are widely known, widely watched,
   and self-fulfilling at best. The card must articulate *why* the retracement
   depth survives out-of-sample and is not arbitraged away. The source (FTMO
   course) is explicitly *not* a track-record source (r1_track_record:
   research); it is pedagogy, not evidence.

2. **"End of impulse move" is undefined and look-ahead prone**: The
   implementation note correctly flags this as a challenge, but it is also
   a correctness requirement. Unless the rule for defining "end of first
   impulse" is specified unambiguously with no look-ahead, the backtest
   results are unreliable. This must be resolved *before* build.

3. **M1/M5 infra blocker**: Same as Set Up 1 — M1 history gap blocks Q02
   enqueue. Lift to M5 minimum.

4. **Falsification criterion is weak**: 100 trades is a small sample. Add a
   regime-split requirement: the edge must persist in both trending and
   ranging market regimes independently (use ADX or ATR-regime split).

### Rework requirements for re-submission
- Add a structural persistence section: explain why the 61.8% retracement
  level is expected to attract resting limit orders (e.g., institutional
  mean-reversion programmes, stop-loss clearing above the swing, liquidity
  absorption). Without this the card fails QB reputable-source criteria R1.
- Define impulse detection precisely: e.g., "highest/lowest M5 close in
  the 08:00–09:00 GMT window; impulse is complete when price closes 3+ pips
  back from the extreme." No ambiguity permitted.
- Replace "61.8%" with a concrete pip or ATR-fraction rule derived from the
  defined impulse range.
- Lift timeframe to M5.
- Strengthen falsification: add regime-split condition.

---

## Disposition summary

| Task | Card | Verdict | Primary reason |
|------|------|---------|----------------|
| 47059b7b | ea-ftmo-set-up-1-quick-move | RECYCLE | Multi-pair signal unimplementable; M1 infra blocker |
| 84931317 | ea-ftmo-set-up-2-fibs-retracement | RECYCLE | No persistence argument; look-ahead risk in impulse detection; M1 infra blocker |

Both cards retain a plausible structural seed. London open momentum and
post-impulse reversion are legitimate edge directions. The rework required
is signal-level, not thesis-level. Gemini should revise and re-submit.
