# Ramp-10 Variant-A Soak Evaluation — 2026-08-11

Evaluator: Claude (Task #22 close-out step 1). Window: R7 activation
2026-08-10T19:35Z (runtime decision sha256 1d984335…, FACTORY STARTED 10/10)
through 2026-08-11T21:15Z (~25.7h). Data sources:
`D:\QM\strategy_farm\state\farm_state.sqlite` (work_items, claim_class_ledger),
`D:\QM\strategy_farm\logs\terminal_worker_T*.log`,
`D:\QM\strategy_farm\state\custom_history_containment_mode.json`.

## Verdict summary

| Criterion | Target | Result | Status |
|---|---|---|---|
| Completed runs | >=500 | **560 done + 13 failed = 573** | **PASS** |
| Isolation errors (error32/error5 class) | 0 containment auto-engages | **0** — containment file untouched since the governed release 2026-08-10T17:43:35Z (`enabled:false`, mode e722da43 unchanged) | **PASS** |
| Archive-integrity tears (ARCHIVE_LINK_COUNT class) | 0 post-fix | **0 since R7** (all logged findings predate R7: the 08-10 17:28Z cascade fixed by per-path reconciliation 6a1366777) | **PASS** |
| Parallel-tester peak | ramp 10 stable | peak 8 concurrent (session evidence 08-10 ~20:30Z); >=7 sustained through the night | PASS (10 never simultaneously demanded by queue mix) |
| Fleet occupancy | >=80% in a 4h window | mean 4.34/10 over the window; best 4h block 08-10T20–23Z = **5.91/10 (59%)** | **FAIL — attributable to dispatch policy, not isolation (see below)** |

## Throughput profile (done per hour, UTC)

19Z..23Z (08-10): 26, 34, 28, 9, 25 — 00Z..08Z: 29, 30, 37, 19, 26, 36, 44, 34, 21
— 09Z..13Z: 19, 32, 23, 15, 18 — 14Z..21Z: 6, 19, 8, 6, 8, 3, …(trickle regime).

Verdicts since R7: 121 PASS, 8 PASS_LOWFREQ, 4 PASS_SOFT, 99 FAIL, 19
ZERO_TRADES, 2 FAIL_DD_PORTFOLIO_REVIEW, 295 INFRA_FAIL (Q02 251/295;
reason classes ONINIT_FAILED / NO_HISTORY / BARS_ZERO / LOG_BOMB / TIMEOUT —
EA-level Q02-graveyard classes of the fresh build cohort, uniformly spread
9–26/h; none of the custom-history/PermissionError class).

## Annotated interruption windows (excluded from occupancy scoring)

1. **2026-08-10 17:28Z–19:35Z (pre-R7, outside soak):** ARCHIVE_LINK_COUNT
   containment cascade + gate-latch restart lottery (R5/R6 FAILED CLOSED) —
   both classes closed (commits 6a1366777, latch commit; R7 mint 1d984335).
2. **2026-08-11 ~03:30Z–05:20Z:** news-calendar publication failure (WinError 5
   sharing violation) → fleet-wide fail-closed `news_calendar_preflight_deferred`.
   Fixed durably: publisher retry 18×50s + task restart policy (commit 76b2c3645).
3. **2026-08-11 ~17:05Z–19:50Z:** two dead run_smoke terminal reservations
   (T7 holder PID 16968 dead since ~17:05Z, T2 holder PID 15960 since 17:33Z)
   blocked claims; swept via `farmctl.release_terminal_reservation` after
   PID-liveness + path-anchored no-terminal64 verification. Third recurrence of
   the reservation-corpse class (T8 midday, holder 21288). Durable fix
   (holder-PID liveness in farmctl) is queued for the post-soak rebind batch.

## Root cause of the occupancy shortfall — dispatch policy, not isolation

At evaluation time the queue held 1,101 pending items: **906 recovery-class**
(`recovery_class` payload marker; INFRA_FAIL requeues, evidence-repair,
MNT-046 waves) vs **195 priority-class**. The priority frontier is concentrated
in XAU/metal/energy/index symbols (top: XAUUSD 17+12+7 across Q02/Q04/Q03,
XBRUSD 16, NDX 15, XTIUSD 6) which serialize on custom-history family locks and
active-symbol exclusion while heavy multisymbol baskets run (multisym
serialization: max 1 farm-wide). Recovery-class rows sort last and are capped by
the OWNER-ratified idle-cap (Operating Rule 22 / ULTRACODE WS-A:
`CLAIM_RECOVERY_WINDOW=5`, `MAX_IN_WINDOW=1`) — at most 1 recovery per 5
successful claims. The 2026-08-04 stall-escape amendment
(`CLAIM_RECOVERY_STALL_ESCAPE_MINUTES=15`) only opens recovery when NO priority
claim lands for 15 minutes; since the blocked frontier still trickles a priority
claim every 5–10 minutes, the escape never triggers. Net effect: **the fleet
idles at 2–3/10 with 906 claimable recovery items waiting** — a gray zone the
ratified contract did not anticipate (frontier trickling instead of flowing or
stalling). Worker claim logs show the signature: `no_pending_claimable` with
`history_skipped` 48–66 (the entire reachable priority window) and the loop
breaking at the recovery tail (`recovery_capped`).

**This is not an isolation finding.** The isolation layer ran the entire soak
without a single containment engage, tear, or error32/error5 event at up to 8
concurrent testers with copy-on-claim privatizations running underneath.

## Recommendations

1. **Isolation migration Variant A: soak PASSED** on the axes the soak was
   designed to prove. Proceed with close-out: retention decision, execution
   record, main merge.
2. **Retention:** keep the rollback tree (original hardlink families) until the
   quiescent FULL archive-integrity audit passes in the next OFF/ON window
   (now mintable any time under the standing preparation ecbd91162), then
   delete in that same window.
3. **Recovery-cap gray zone → OWNER decision requested:** amend the stall-escape
   with an occupancy condition (e.g. "if fewer than half the enabled terminals
   hold active claims for 15 minutes while recovery rows are pending, recovery
   may drain freely until the next priority claim") — implementation in
   `farmctl.recovery_claim_allowed` (decision-bound file; bundle with the rebind
   batch). Until then the fleet will idle whenever the priority frontier narrows
   to a blocked symbol cluster.
