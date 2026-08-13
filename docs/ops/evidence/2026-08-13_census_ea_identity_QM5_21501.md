# Census EA identity QM5_21501 — build evidence

**Date:** 2026-08-13
**Author:** Claude
**Plan:** `docs/research/PATTERN_PERMISSION_FILTER_PLAN_V2_2026-08-13.md`, finding **A5**
("Der Zensus bekommt eine eigene, hash-gebundene Zensus-EA-Identität mit
Lineage-Manifest. Ohne rechtmäßiges ausführbares Subjekt läuft kein Trial.")
**Branch:** `agents/board-advisor`

---

## 1. What was built

`QM5_21501_balke-gmt3-range-breakout-ppcensus` — the executable subject of the P3
pattern-permission census for the first frozen-cohort sleeve
(QM5_13213 / USDJPY.DWX).

### Identity band convention (established here)

| Band | Meaning |
|---|---|
| 21001-21499 | promotion challengers (compiled, fixed configuration) |
| 21500+ | census instruments (open trial surface, measurement only) |

21001 was already claimed by the in-flight exit-surgery challenger (router task
`661a36b1-c7b6-4fcb-8bf9-1028326e2271`, gemini, IN_PROGRESS); the census
instrument was allocated at 21501 rather than colliding with it.

A census instrument must never reach a book: its parameter surface is
deliberately open (one predicate id per trial), which is exactly what a live EA
must not have. Promotion (P4) compiles surviving predicates into a **fixed**
profile under a fresh 21001-21499 identity.

---

## 2. Registry chain (strictly serial, per build_ea SOP)

| Step | Command | Result |
|---|---|---|
| Reserve id | `farmctl.py reserve-ea-ids --slug balke-gmt3-range-breakout-ppcensus --strategy-id 6e967762-b26d-59a3-b076-35c17f2e7c36 --owner Claude --start-after 21500` | `ea_id=21501`, reserved under `_acquire_registry_lock` |
| Magic row | appended to `framework/registry/magic_numbers.csv` | `21501,balke-gmt3-range-breakout-ppcensus,0,USDJPY.DWX,215010000,2026-08-13,Claude,active` |
| Collision pre-check | grep `^21501,` and `,215010000,` | 0 rows each, before the append |
| Resolver regen | `python framework/scripts/update_magic_resolver.py` | `15919 rows kept, 0 dropped, sha=397592BD41EAD7A4...` |

### Resolver verification (independent re-read, not the generator's own claim)

```
rows: 15919 15919 15919 15919
21501 row indices: [15918]
  ea_id=21501 slot=0 symbol=USDJPY.DWX magic=215010000
formula ea_id*10000+slot: OK
duplicate magics in resolver: [] count 0
```

Zero duplicate magics fleet-wide.

The strategy_id is the parent's, unchanged: this is a measurement derivative of
QM5_13213, not a new strategy.

---

## 3. The A1 / A2 structural fix

**A1 — the order-placement defect.** `QM5_13213:310-313` calls
`QM_TM_OpenPosition(buy_req, buy_ticket)` **inside** `Strategy_EntrySignal` and
returns only the SELL leg via `req` (`:315-317`). A veto applied to the returned
request is therefore a no-op for longs. Without this fix, a buy-blocking
predicate would have measured as "no effect on longs" while the EA silently kept
trading them — a wrong answer with no error surfacing. (QM5_13301 carries the
same shape at `:334-341, :543-547`.)

In QM5_21501 signal generation is free of order-placement side effects:

```
Strategy_BuildStraddlePlan(plan)     // fills plan, places nothing
   -> Census_Permission()            // closed-bar, fail-closed verdict
   -> QM_PPS_Decide(plan, perm)      // pure decision
   -> QM_TM_OpenPosition per permitted leg
```

**A2 — day completion follows the decision, not the signal.** The parent sets
`g_strategy_orders_day_key` before returning (`:316`). Here the day closes only
when `decision.mark_day_complete` is true, so an invalid-permission day (history
gap) stays **open** instead of being silently recorded as a deliberate no-trade
day.

`Strategy_BuildStraddlePlan` still caches the resolved range (the exit hook
reads it) and the ATR-band skip flag (a strategy decision, independent of any
permission verdict). Both are idempotent per day and neither can create an
order.

**Why `QM_PPS_WithdrawForbiddenPendings` is not called:** the reference bar is
D1 shift 1, invariant across a trading day, so the verdict cannot flip intraday
and there is nothing to withdraw against. An instrument with an intraday
reference TF would need it.

---

## 4. Two fail-closed defects found and closed during the build

### 4.1 Unimplemented predicate ids measured as "no effect"

`QM_PP_Evaluate`'s `default:` branch returns `false` for an unknown id
(`QM_PatternPermission.mqh:709-710`). Correct for evaluation — an unknown
pattern must not block — but a **measurement hazard**: the census feeds a
predicate id in from outside the binary. A kill-list or typo'd id would never
fire, produce results identical to the control, and be recorded in the ledger as
"this predicate has no effect".

Closed by adding `QM_PP_IsImplemented()` (generated from the enum, not
hand-typed) and making `QM_PP_ProfileAddBuy` / `QM_PP_ProfileAddSell` reject any
id it does not cover. QM5_21501 returns `INIT_FAILED` with
`PP_CENSUS_CONFIG_INVALID{reason:"predicate_not_implemented"}` on that
rejection, so such a trial cannot run at all.

Pinned by four new contract tests asserting **three-way set equality** —
enum == `QM_PP_Evaluate` case labels == `QM_PP_IsImplemented` case labels —
plus scope (exactly 77) and kill-list/control exclusion. Adding an enum member
without wiring it now fails the suite.

Measured at time of writing: enum 77, evaluate 77, implemented 77, symmetric
difference empty.

### 4.2 Enum inputs are unparseable in generated set files

The first generated set file contained:

```
strategy_pp_direction=QM_PPC_BUY
```

`gen_setfile.ps1` copies the input's **source default text** verbatim, and MT5
set files store enum inputs as integers. MT5 cannot parse the symbol name back,
so **every SELL cell would have silently run as BUY** — half of the 1,386-cell
census wrong, with no error anywhere.

Closed by making `strategy_pp_direction` a plain `int` with a **literal**
default (`= 0`, not `= QM_PPC_BUY` — a macro leaks the same way), plus an
`OnInit` rejection of any value outside {0,1}. Regenerated set file now emits
`strategy_pp_direction=0`.

**Related pre-existing finding, not fixed here:** 66 committed set files carry
non-numeric values of the same class, e.g.
`QM5_10061_connors-trin3-d1_*_backtest.set: strategy_signal_tf=PERIOD_D1`.
Whether MT5 resolves those or silently falls back to the input default has not
been established. Logged as a follow-up; it does not affect the census.

---

## 5. Verification

| Check | Command | Result |
|---|---|---|
| Compile | `tools/strategy_farm/compile_ea.py --ea-id 21501 --force` | `COMPILED`, **0 errors, 0 warnings**, `SINGLE_SYMBOL_OK` |
| Build check | `build_check.ps1 -EALabel QM5_21501_... -SkipCompile` | **PASS**, 0 failures, 0 warnings |
| Guardrails | `tools/strategy_farm/validate_build_guardrails.py <ea dir>` | **PASS**, 0 findings, 2 files checked |
| Spec | `framework/scripts/validate_spec_doc.py <ea dir>` | **PASS** (1 PASS, 0 FAIL) |
| Contract tests | `pytest framework/scripts/tests/test_pattern_permission_contract.py` | **26 passed** (22 prior + 4 new) |
| Include actually compiled | synced copy in all 16 terminal profiles contains `QM_PP_IsImplemented`, mtime 2026-08-13 14:11 UTC; EA compiled 0/0 against it at 14:28 UTC | confirmed |

Build check report: `D:\QM\reports\framework\21\build_check_20260813_142819.json`

Four new events registered via `framework/scripts/generate_event_vocabulary.py`
(302 events total): `PP_CENSUS_INIT`, `PP_CENSUS_BLOCK`, `PP_CENSUS_SUMMARY`,
`PP_CENSUS_CONFIG_INVALID`. The regeneration also absorbed a backlog of
previously-unregistered events from other already-committed EAs.

---

## 6. Operational hazard hit during this build — record it

Running `framework/scripts/build_check.ps1 -SkipCompile` **without `-EALabel`**
invoked `Update-SetFileBuildHash` across the whole repo and modified **9,072 set
files**: it rewrote every `build_hash` header line *and* prepended a UTF-8 BOM.

```
modified: 9078  keep: 6  revert: 9072
non-.set files in revert list: 0
```

All 9,072 were reverted with `git restore --pathspec-from-file=...`; the working
tree was clean at session start, so every one of them was attributable to that
run and nothing of another agent's was touched. Verified afterwards: only the
six intended files remained modified.

**Rule:** always pass `-EALabel <label>` when build-checking a single EA. The
unscoped form is a fleet-wide mutation, and the BOM it adds is the same class of
encoding hazard already recorded for tester commissions and German-locale
reports.

---

## 7. Files

| File | Status |
|---|---|
| `framework/EAs/QM5_21501_balke-gmt3-range-breakout-ppcensus/*.mq5` | new |
| `framework/EAs/QM5_21501_balke-gmt3-range-breakout-ppcensus/*.ex5` | new (0/0 compile) |
| `framework/EAs/QM5_21501_balke-gmt3-range-breakout-ppcensus/SPEC.md` | new |
| `framework/EAs/QM5_21501_.../sets/*_USDJPY.DWX_H1_backtest.set` | new |
| `framework/include/QM/QM_PatternPermission.mqh` | +`QM_PP_IsImplemented`, profile builders now reject unimplemented ids |
| `framework/include/QM/QM_MagicResolver.mqh` | regenerated (15919 rows, 0 dropped) |
| `framework/registry/ea_id_registry.csv` | +1 row (locked allocation) |
| `framework/registry/magic_numbers.csv` | +1 row |
| `framework/registry/event_vocabulary.json` | regenerated (302 events) |
| `framework/scripts/tests/test_pattern_permission_contract.py` | +4 tests (26 total) |

---

## 8. What is still open before P3 can run

1. **Predicate fixture suite** — per-predicate positive / negative / boundary
   cases. The 26 contract tests pin structure and scope; they do not yet prove
   each of the 77 predicates fires on the right bar shape. This is the
   "no shortcuts" core and is next on Claude's side.
2. **Remaining 8 sleeves** — one census instrument per parent EA of the frozen
   cohort, same chain.
3. **E1 / E2 / E3** — dev-sweep emitter, q16-lineage emitter, cap-pool isolation
   (dispatched to Codex, ticket `50b0f355-cb89-4c8a-a064-7e6f7c257bbd`).
4. **P2.5 pre-registration** — source-derived promotion candidates fixed before
   any census return is visible (the OWNER E0-1 firewall: the census MEASURES,
   it must not SELECT).
5. **P3 itself** — 9 pairs x 77 predicates x 2 directions x 2 runs = 2,772
   backtests, ~46 h, parent-serial so the normal queue keeps breathing.
