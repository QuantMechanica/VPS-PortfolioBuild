# FTMO Book 3 execution preregistration

Date: 2026-07-29  
Decision authority: OWNER  
Execution scope: isolated BACKTEST-ONLY measurement while the autonomous Factory remains OFF

## Objective

Measure the OWNER-locked three-sleeve FTMO research book on one simulated USD 100,000
account without weakening any admission gate:

| Slot | Standalone EA | Symbol | Joint magic | Cadence |
|---|---|---|---:|---|
| 0 | QM5_9936 | USDJPY.DWX | 201810000 | host `OnTick` |
| 1 | QM5_10145 | XAUUSD.DWX | 201810001 | non-host D1 dispatch |
| 2 | QM5_13108 | XTIUSD.DWX | 201810002 | non-host D1 dispatch |

QM5_13301 is not a member. The only authoritative three-sleeve set is
`QM5_20181_ftmo-joint-multisym-timer_USDJPY.DWX_H1_book3_9936_10145_13108.set`.

## Immutable safety boundary

- `FACTORY_OFF.flag` must remain present and byte-identical for every isolated run.
- The global Factory mutation lock must cover each claim, tester execution, evidence harvest,
  and receipt publication.
- Factory scheduled tasks remain disabled. T5 and T_Live are forbidden; T_Live and its
  AutoTrading state are never touched.
- QM5_20181 remains a tester-only measurement EA. `RISK_PERCENT=0`, `RISK_FIXED=1000` per
  enabled sleeve, `prop_phase=OFF`, and stress rejection `0` are mandatory.
- No live/demo/FTMO set, deployment manifest, purchase, paid Challenge, or Factory-ON action
  is authorized by this measurement.
- Existing user-owned canonical worktree changes are outside this scope and must not be
  overwritten or normalized.

## Source and identity gate

Before any tester run:

1. The deterministic registry must contain exactly the three slot bindings above.
2. QM5_9936, QM5_10145, QM5_13108, and QM5_20181 must be strict-compiled serially from one
   repository/framework vintage with zero errors and zero warnings.
3. The execution bundle must bind the repository commit, dirty-scope exclusion, MQ5, EX5,
   included framework tree, setfile, symbol specification, history, cost, calendar, rulepack,
   terminal, model, and date window hashes.
4. Every run must use the same reserved terminal, Model 4, the same 2018-07-02 through
   2025-12-31 window, and matched commission/cost inputs.
5. A missing, stale, mismatched, or unhashable operand is `SETUP_DATA_MISSING` or
   `SETUP_DATA_MISMATCH`, never a strategy verdict.

## Incremental fidelity ladder

The order is fixed. A failed rung stops all later rungs; no tolerance or strategy parameter
may be changed within this evidence vintage.

1. **Runner control:** fresh standalone QM5_9936 versus QM5_20181 runner-only.
2. **Two-sleeve admission:** fresh standalone QM5_10145 versus joint slot 1, while joint slot 0
   must remain identical to the admitted runner control.
3. **Three-sleeve admission:** fresh standalone QM5_13108 versus joint slot 2, while joint slots
   0 and 1 must remain identical to their admitted controls.

For every comparison the hard criterion is:

- `match_rate == 1.0`;
- zero unmatched joint trades;
- zero unmatched standalone trades;
- entry time, close time, net account currency, and volume equal under the comparator's fixed
  half-cent / half-volume-step numerical tolerances;
- no unadjudicated timing, news, cost, symbol, or execution mismatch.

The D1 satellites are admitted only if the joint adapter reproduces the standalone first-tick
new-bar semantics. A timer approximation, shifted-entry waiver, or count-only comparison is a
FAIL.

## Joint-account measurement gate

Only after all three fidelity rungs pass may the authoritative Book-3 run be treated as a joint
account measurement. Evidence must include:

- the complete per-magic closed-trade streams;
- one synchronized account balance/equity trace with intratrade lows;
- Prague-midnight daily anchors, DST handling, trading-day count, pending/open-position state;
- commission, spread, swap, margin, and rejected-order evidence;
- deterministic reproduction and Python/MQL governor parity/fault-injection evidence.

Q08 `FAIL_SOFT` remains visible evidence debt and is never rewritten as PASS. It does not excuse
any Book-3 fidelity, setup, or FTMO money-gate failure.

## Predeclared FTMO decision thresholds

The current `FTMO_2S_100K_SWING_V1` research contract is evaluated without local threshold
changes:

- Phase-1 pass probability point estimate at least 80%;
- Phase-1 lower 95% bound at least 70%;
- official-rule breach probability upper 95% bound at most 10%;
- conditional Phase-2 pass probability at least 85%;
- joint two-phase pass probability at least 65%;
- zero unadjudicated fidelity or operational defects.

The first completed exact-profile Free Trial/shadow with zero operational defects is a separate
later gate. Official FTMO rules must be refreshed and hash-bound no more than seven days before
any money decision. A paid Challenge still requires a separate explicit OWNER purchase decision.

## Outcomes

- **ADMITTED_FOR_SHADOW:** every source, identity, fidelity, joint-equity, governor, and
  probability gate above passes. This authorizes preparation of a Free Trial/shadow dossier
  only.
- **REWORK_REQUIRED:** a strategy/fidelity/probability gate fails. Preserve the evidence, stop
  the ladder, and create a new version before another measurement.
- **SETUP_BLOCKED:** an environment, history, calendar, cost, capacity, or evidence-integrity
  prerequisite fails. Repair the setup and repeat the same frozen measurement; do not classify
  the book as strategy FAIL.

Factory restart readiness is evaluated separately. Even an admitted FTMO Book 3 can only trigger
preparation of a restart package; it cannot remove `FACTORY_OFF.flag` or invoke `Factory_ON.ps1`.
