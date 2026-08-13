# QM5_21501_balke-gmt3-range-breakout-ppcensus - Strategy Spec

**EA ID:** QM5_21501
**Slug:** `balke-gmt3-range-breakout-ppcensus`
**Source:** instrumented derivative of `QM5_13213_balke-gmt3-range-breakout`
(strategy_id `6e967762-b26d-59a3-b076-35c17f2e7c36`, unchanged)
**Author of this spec:** Claude
**Last revised:** 2026-08-13

---

## 0. What this EA is — and what it must never become

This is a **census instrument**, not a deployable strategy. It exists so the P3
pattern-permission census (plan v2, `docs/research/PATTERN_PERMISSION_FILTER_PLAN_V2_2026-08-13.md`)
has a lawful executable subject: finding **A5** — no trial without one.

**Identity band convention (established here):**

| Band | Meaning |
|---|---|
| 21001-21499 | promotion challengers (compiled, fixed configuration) |
| 21500+ | census instruments (open trial surface, measurement only) |

A census instrument must never reach a book. Its parameter surface is
deliberately open — one predicate id is fed in per trial — and that is precisely
what a live EA must not have. Promotion (P4) compiles the surviving predicates
into a **fixed** profile under a fresh 21001-21499 challenger identity, which
then runs the standard Q02->Q10 cascade on its own merits.

---

## 1. Strategy Logic

Mechanics are the parent's, unchanged: build the completed 03:00-06:00
GMT+3-equivalent H1 range, place a buy stop at the range high and a sell stop at
the range low at 06:00, skip the day when range height is outside
[0.4x, 2.5x] ATR(14,H1), close at 18:00 GMT+3-equivalent, on an opposite
range-side touch, or trail to the prior two completed H1 lows/highs past +1R.

**One structural change — the A1 fix.** The parent places the BUY leg *inside*
`Strategy_EntrySignal` (`QM5_13213:310-313`) and returns only the SELL via `req`
(`:315-317`). A veto applied to the returned request is therefore a no-op for
longs: a buy-blocking predicate would have measured as "no effect on longs"
while the EA silently kept trading them. Here signal generation is free of
order-placement side effects:

```
Strategy_BuildStraddlePlan(plan)   // fills plan, places nothing
        -> Census_Permission()      // closed-bar, fail-closed verdict
        -> QM_PPS_Decide(plan, perm) // pure decision
        -> QM_TM_OpenPosition per permitted leg
```

**A2 — day completion follows the decision, not the signal.** The parent sets
`g_strategy_orders_day_key` before returning (`:316`). Here the day is marked
complete only when `decision.mark_day_complete` is true. If permission is
invalid (a history gap), the day stays **open**, so a data gap cannot be
silently recorded as a deliberate no-trade day.

Everything else — window, range construction, ATR band, trailing, evening flat,
news, risk, magic — is identical to the parent, so the census measures the
filter and nothing else.

---

## 2. Parameters

Strategy parameters are the parent's, with identical defaults, and are **not
tuned here**: the census varies the predicate, never the strategy, so every cell
stays comparable to the same control.

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_range_start_hour` | 3 | 0-23 | First GMT+3-equivalent hour in the range. |
| `strategy_range_end_hour` | 6 | 1-24 | First hour after the range; order placement hour. |
| `strategy_exit_hour` | 18 | 0-23 | Evening resolution: cancel pendings and close positions. |
| `strategy_atr_period` | 14 | >=1 | ATR period for the range-height band. |
| `strategy_min_range_atr_mult` | 0.4 | >0 | Minimum range height in ATR multiples. |
| `strategy_max_range_atr_mult` | 2.5 | >0 | Maximum range height in ATR multiples. |
| `strategy_trail_trigger_r` | 1.0 | >=0 | Profit in R before the two-bar trail engages. |
| `strategy_range_scan_bars` | 36 | >=6 | Closed H1 bars scanned to rebuild the session range. |

### Census trial surface

Exactly `{predicate_id, direction}` — matching the `PREDICATE_ABLATION` lever's
`planned_trials` shape. Nothing else varies across the 154 cells of a sleeve.

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_pp_enabled` | `false` | `false` = the control cell. |
| `strategy_pp_predicate_id` | 0 | `QM_PatternId` value under test. |
| `strategy_pp_direction` | 0 | `0` = gate LONG entries, `1` = gate SHORT entries. |

`strategy_pp_direction` is a plain `int`, not an enum, deliberately. MT5 set
files store enum inputs as integers, and `gen_setfile.ps1` writes the input's
source default verbatim — an enum would emit `strategy_pp_direction=QM_PPC_BUY`
into the `.set`, which MT5 cannot parse back. Every SELL cell would have
silently run as BUY and half the census would have been wrong with no error
surfacing. Caught on the first generated set file, 2026-08-13.

**Deliberately not inputs:** reference timeframe (`PERIOD_D1`) and closed shift
(`1`) are compile-time constants. The census fixes 1,386 cells; every extra knob
is another way for one setfile typo to corrupt the whole grid. A sleeve that
needs a different reference bar gets its own instrument.

### Fail-closed init contract

`OnInit` returns `INIT_FAILED`, with a `PP_CENSUS_CONFIG_INVALID` log line, when:

| Condition | Why it must abort |
|---|---|
| `strategy_pp_enabled=false` but `predicate_id != 0` | The cell would run as a control while the ledger recorded it as a trial. |
| `strategy_pp_enabled=true` but `predicate_id <= 0` | A trial with no subject. |
| `predicate_id` not implemented in `QM_PatternPermission.mqh` | `QM_PP_Evaluate`'s `default:` returns false, so the predicate would never fire, the cell would come out identical to the control, and the ledger would record "no effect" for something never tested. `QM_PP_ProfileAddBuy/AddSell` reject it; this EA aborts on that rejection. |

The control cell (`enabled=false`) traverses the **same** code path via
`Census_Permission()` returning an all-allow valid verdict — control and trial
must differ in the predicate only, not in the plumbing they cross.

---

## 3. Symbol Universe

**Designed for:** `USDJPY.DWX` only — the parent's live Q10 sleeve, and the
first of the nine frozen-cohort pairs to be censused (plan v2, P3).

**Explicitly NOT for:** anything else. This is a measurement fixture bound to one
(EA, symbol) pair; another pair gets another instrument so lineage stays
one-to-one and hash-bindable.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1` — pattern-permission reference bar, shift 1 (closed) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

The D1 reference bar at shift 1 is invariant across a trading day, so the
permission verdict cannot flip intraday. That is why this EA does not call
`QM_PPS_WithdrawForbiddenPendings` — there is no mid-day flip to withdraw
against. An instrument with an intraday reference TF would need it.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Control cell: the parent's rate. Trial cells: at or below it — a blacklist can only remove entries, never add them. |
| Typical hold time | Same-day intraday, 06:00 to no later than 18:00 GMT+3-equivalent. |
| Expected drawdown profile | Parent's, minus whatever the tested predicate removes. |
| Regime preference | Unchanged from the parent. |
| Win rate target (qualitative) | not applicable — this EA is measured against its own control, not against an absolute bar. |

### Census telemetry

Emitted for `emit_dev_sweep.py` to bind per trial. `fire_count` is consumed by
Q15's categorical eligibility gate, which rejects a rarely-firing predicate
*before* comparing objectives — that is what closes the small-sample-winner hole.

| Event | Field | Meaning |
|---|---|---|
| `PP_CENSUS_INIT` | `profile_key` | Full cache-key identity of the profile under test. |
| `PP_CENSUS_BLOCK` | per-occurrence | Emitted whenever the decision differs from the plan. |
| `PP_CENSUS_SUMMARY` | `days_evaluated` | Days a plan existed and permission was consulted. |
| | `fire_count` | Days the predicate blocked the tested direction. |
| | `legs_suppressed` | Entry legs actually withheld. |
| | `invalid_days` | Days permission was unavailable (fail-closed, no trade). |

---

## 6. Source Citation

**Source:** no new external source. This EA is a measurement derivative of
`QM5_13213_balke-gmt3-range-breakout` and inherits its citation: René Balke's
Range Breakout, exact parameters per OWNER-verified agy analysis (2026-07-13).

**Filter under test:** `framework/include/QM/QM_PatternPermission.mqh` — 77
predicates ported from OWNER's own QuantRangePRO `Patterns.mqh`, with the source
reference's three defects deliberately **not** ported (forming-bar repaint,
fail-open on invalid state, a single global lookback that made two predicates
dead code). Kill-list material (SMC/ICT/FVG/order-block/BOS/ChoCh, Wyckoff,
Hurst, the mislabelled correlation predicate) is excluded by OWNER decision and
pinned by `framework/scripts/tests/test_pattern_permission_contract.py`.

**Governing plan:** `docs/research/PATTERN_PERMISSION_FILTER_PLAN_V2_2026-08-13.md`
(Codex-reviewed, OWNER-ratified 2026-08-13).

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Census (all cells) | RISK_FIXED | $1,000 per trade |
| Live | **not applicable** | This EA is never deployed. See section 0. |

`RISK_FIXED` also makes the census clean: with no equity feedback, a blocked
entry cannot change the sizing of any other trade, so cells differ only by the
entries the predicate removed.

ENV->mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-13 | Census instrument for the P3 pattern-permission census; carries the A1/A2 order-placement fix | plan v2 findings A1, A2, A5 |
