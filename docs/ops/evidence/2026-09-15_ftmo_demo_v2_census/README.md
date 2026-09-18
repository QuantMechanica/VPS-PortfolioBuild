# FTMO demo book v2 — admission census (READ-ONLY, canonical merge)

Book sprint `docs/ops/BOOK_SPRINT_2026-09-20.md` item **F4** (decision **F3**: FTMO demo
book v2 = the DXZ v2 roster on FTMO broker symbol names, same sha-bound binaries, no
rebuild, no qualification claim), ticket **42a437a4** (binding due Wed 2026-09-16 18:00Z).

**Status: this is the orchestrator-directed RECYCLE merge that closes ticket 42a437a4.**
Base = `slot1_census_v2/ftmo_demo_v2_census_slot1.py` (1 ADMIT / 16 ADMIT_CONDITIONAL /
11 EXCLUDE), with corrections (i)–(v) from the review verdict recorded
2026-09-15T10:30:41Z applied. This supersedes the v1 census (commit `9a06adf9bd`, 24
ADMIT / 4 EXCLUDE) and the concurrent "slot-3 second opinion" (commit `f66a996f32`, +2
ADMIT) — both artifacts of the same 3-session `run_agent_orchestration_task.py
--max-sessions 3` fan-out collision recorded in `slot1_census_v2/COLLISION.md`.

## Hard-limit compliance (all honoured)

Read-only against both live terminals. No `terminal64.exe` start; no writes into any FTMO
or T_Live data dir; **no recompile** (binaries are bound by sha256, never rebuilt — a
rebuilt `.ex5` is a new identity by company policy); no chart attach; no governor policy
change. The only files written are in this evidence dir plus the re-runnable tool at
`tools/strategy_farm/ftmo_demo_v2_census.py`. The governor input deltas below are a
**PROPOSAL ONLY** — applied nowhere.

## Result

| | v1 (superseded) | slot-1 base | **this merge** |
|---|---:|---:|---:|
| sleeves | 28 | 28 | **28** |
| ADMIT | 24 | 1 | **16** |
| ADMIT_CONDITIONAL | — | 16 | **0 (tier eliminated, see below)** |
| EXCLUDE | 4 | 11 | **12** |

The ADMIT_CONDITIONAL tier is **eliminated by correction (ii)**: every row that used to
carry a "needs an artifact-only rebuild" condition either clears to ADMIT under
correction (i) (bare base-name match) or moves to EXCLUDE (a rebuild is not admitted as
a precondition for this book). `decision` is now strictly binary.

## Corrections applied to the slot-1 base (orchestrator merge verdict, verbatim numbering)

* **(i)** `resolver_fix_present=False` alone is **not** a blocker for `chart-symbol-only*`
  EAs whose FTMO symbol equals the DXZ registry base name (bare FX pairs, XAUUSD, XAGUSD)
  — the same pre-fix (July-built) binaries already initialize fully on T_Live today with a
  bare broker symbol. Spot-checked against three T_Live per-EA logs
  (`C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/QM5_<ea>_ea-<ea>.log`): QM5_1556 (XAUUSD,
  built 2026-07-13), QM5_10706 (GBPUSD, built 2026-07-13), QM5_1567 (EURUSD, built
  2026-07-19) all show `SYMBOL_GUARD_INIT` with a bare `symbol` field followed by
  `NEWS_CALENDAR_LOADED` / `KILL_SWITCH_INIT` / `CHART_UI_INIT` — i.e. `OnInit` completed,
  no `FRAMEWORK_INIT_FAILED`. Encoded as `bare_name_match` in the census.
* **(ii)** No "artifact-only rebuild" precondition is admitted for this book (identity
  rule). A row that would need a rebuild to attach — either because it is a non-bare
  name match still blocked on the magic-resolver fix (`10919`/USOIL.cash), or because
  `registry_snapshot_stale` (magic reserved after the bound binary was built — did not
  fire on this roster), or because the canonical-symbol mismatch itself can only be
  closed by a registry re-symbol (the six index sleeves + USOIL if it weren't already
  alias-resolved) — is **EXCLUDE**, not ADMIT_CONDITIONAL.
* **(iii)** A magic collision against a *currently-running* FTMO demo chart
  (`magic_held_by_other_binary`) is resolved by the deployment plan itself: **the v1
  profile is detached before the v2 profile loads.** It is recorded as
  `magic_collision_resolution=resolved_by_profile_replacement` and does **not** gate the
  decision. Affects 2 ADMIT rows: `QM5_10706`/GBPUSD (magic `107060001`) and
  `QM5_11421`/EURUSD (magic `114210000`). A *registry* cross-registration
  (`reg_collision`, a different EA owns the magic in `magic_numbers.csv`) is a distinct,
  still-excluding problem — none present in this roster.
* **(iv)** Governor input deltas below are re-derived from the governor's 8 live magics
  **UNION the resulting 16-row ADMIT set** (no ADMIT_CONDITIONAL tier to fold in).
* **(v)** Every EXCLUDE reason remains bound to a file:line, registry lookup, or a probed
  terminal source (unchanged from the slot-1 base).

## Files

- `roster_ftmo_demo_v2.json` — one row per sleeve (schema `qm.ftmo-demo-v2-admission-census/v3-merged`).
- `ftmo_symbol_probe.json` — read-only FTMO terminal symbol-inventory probe (ticks, history, symbol-DB scan, terminal+Expert log scan), re-generated on every run.
- `README.md` — this file.
- `tools/strategy_farm/ftmo_demo_v2_census.py` — reproduces the census end to end (read-only). Re-run: `python -X utf8 tools/strategy_farm/ftmo_demo_v2_census.py`.
- `slot1_census_v2/` — the merge base (slot-1's independent rework); preserved for the record, not re-run.
- `slot3_reconciliation/` — the concurrent sibling's "second opinion"; preserved for the record, **not** the merge base per the orchestrator verdict.
- `ticket_payload.json` — the ticket payload.

## Full roster (28 sleeves)

| ea_id | dxz_symbol | ftmo_symbol | symbol_source | handling_class | slot | magic | coll. | risk % | decision |
|---:|---|---|---|---|---:|---:|:--:|---:|---|
| 41470 | USDJPY.DWX | USDJPY | alias(x-acct) | symbol-input-slot | 0 | 414700000 | n | 0.5904 | **ADMIT** |
| 1556 | XAUUSD.DWX | XAUUSD | alias(x-acct) | chart-symbol-only+non-chart-reads | 4 | 15560004 | n | 0.5407 | **ADMIT** |
| 1567 | EURUSD.DWX | EURUSD | native-2026-09-06 | chart-symbol-only | 7 | 15670007 | n | 0.1848 | **ADMIT** |
| 10403 | XAUUSD.DWX | XAUUSD | alias(x-acct) | chart-symbol-only | 2 | 104030002 | n | 0.2179 | **ADMIT** |
| 10513 | XAUUSD.DWX | XAUUSD | alias(x-acct) | chart-symbol-only | 3 | 105130003 | n | 0.2987 | **ADMIT** |
| 10700 | XAUUSD.DWX | XAUUSD | alias(x-acct) | chart-symbol-only | 3 | 107000003 | n | 0.0130 | **ADMIT** |
| 10706 | GBPUSD.DWX | GBPUSD | alias(x-acct) | chart-symbol-only | 1 | 107060001 | **YES→resolved** | 0.0527 | **ADMIT** |
| 10939 | GBPUSD.DWX | GBPUSD | alias(x-acct) | chart-symbol-only | 1 | 109390001 | n | 0.1958 | **ADMIT** |
| 11165 | AUDCAD.DWX | AUDCAD | ftmo-ticks-dir | chart-symbol-only | 2 | 111650002 | n | 0.5082 | **ADMIT** |
| 11165 | EURUSD.DWX | EURUSD | native-2026-09-06 | chart-symbol-only | 0 | 111650000 | n | 0.4097 | **ADMIT** |
| 11421 | AUDUSD.DWX | AUDUSD | ftmo-ticks-dir | chart-symbol-only | 3 | 114210003 | n | 0.3213 | **ADMIT** |
| 11421 | EURUSD.DWX | EURUSD | native-2026-09-06 | chart-symbol-only | 0 | 114210000 | **YES→resolved** | 0.3247 | **ADMIT** |
| 11708 | EURUSD.DWX | EURUSD | native-2026-09-06 | chart-symbol-only | 0 | 117080000 | n | 0.5449 | **ADMIT** |
| 12567 | XAUUSD.DWX | XAUUSD | alias(x-acct) | chart-symbol-only | 3 | 125670003 | n | 0.7848 | **ADMIT** |
| 12989 | XAUUSD.DWX | XAUUSD | alias(x-acct) | chart-symbol-only | 3 | 129890003 | n | 0.2275 | **ADMIT** |
| 13213 | USDJPY.DWX | USDJPY | alias(x-acct) | chart-symbol-only | 0 | 132130000 | n | 0.0443 | **ADMIT** |
| 1537 | XAGUSD.DWX | XAGUSD | native-2026-09-06 | chart-symbol-only | 1 | 15370001 | YES | 0.0769 | **EXCLUDE** |
| 9641 | WS30.DWX | US30.cash | alias(x-acct), **no on-account corroboration** | chart-symbol-only | 2 | 96410002 | n | 0.0104 | **EXCLUDE** |
| 10440 | NDX.DWX | US100.cash | alias(x-acct) | chart-symbol-only | 3 | 104400003 | n | 0.0584 | **EXCLUDE** |
| 10911 | GDAXI.DWX | GER40.cash | alias(x-acct) | chart-symbol-only | 3 | 109110003 | n | 0.1260 | **EXCLUDE** |
| 10919 | XTIUSD.DWX | USOIL.cash | alias(x-acct) | chart-symbol-only | 1 | 109190001 | n | 0.8578 | **EXCLUDE** |
| 11132 | SP500.DWX | UNVERIFIED | unverified | chart-symbol-only | 0 | 111320000 | n | 0.4272 | **EXCLUDE** |
| 12567 | XNGUSD.DWX | UNVERIFIED | unverified | chart-symbol-only | 2 | 125670002 | n | 0.9577 | **EXCLUDE** |
| 12778 | AUDUSD.DWX | AUDUSD | ftmo-ticks-dir | symbol-input-slot+multi-symbol | 0 | 127780000 | n | 0.4393 | **EXCLUDE** |
| 13013 | NDX.DWX | US100.cash | alias(x-acct) | chart-symbol-only | 0 | 130130000 | n | 0.0105 | **EXCLUDE** |
| 13117 | EURGBP.DWX | UNVERIFIED | unverified | symbol-input-slot+multi-symbol | 0 | 131170000 | n | 0.4100 | **EXCLUDE** |
| 13128 | NDX.DWX | US100.cash | alias(x-acct) | chart-symbol-only | 0 | 131280000 | n | 1.1028 | **EXCLUDE** |
| 13301 | GDAXI.DWX | GER40.cash | alias(x-acct) | chart-symbol-only | 10 | 133010010 | n | 0.0648 | **EXCLUDE** |

Regenerate this table from `roster_ftmo_demo_v2.json` at any time.

## EXCLUDE reasons (each bound to evidence)

**A — blocking `.DWX` trading-logic literal (1 sleeve: 1537/XAGUSD).** `QM5_1537`'s
`strategy_calendar_symbol` exemption (`QM5_1537_MonthlySleeveCalendar.mqh:312`) depends on
an input added by `dcaeca68f5` (2026-09-06 20:03:01Z); the bound binary
(`deploy_staging`, sha `142a019e773a…`) was built **2026-08-16**, before that input
existed, so the exemption is refused and the literal (`XAGUSD.DWX`) blocks. Per
correction (ii), fixing this needs a rebuild — EXCLUDE for this book. (The v1 census
admitted this row on a prose reading of the same literal; superseded.)

**B — needs a rebuild for the resolver fix, and the FTMO name is not a bare match
(1 sleeve: 10919/USOIL.cash).** `QM5_10919` resolves `XTIUSD.DWX` → `USOIL.cash` only via
the explicit code alias in `QM_MagicSymbolCanonical` (`QM_MagicResolver.mqh:134`), which
requires the same suffix-tolerant compare added by `4fb47bd3b5` (2026-09-06). The bound
binary (`deploy_staging`, built 2026-08-11) predates it. Correction (i)'s bare-name
exemption does not apply (the FTMO name differs from the DXZ base name) — EXCLUDE per
correction (ii).

**C — canonical symbol mismatch, unresolvable without a registry re-symbol (5 index
sleeves: 10440/NDX, 10911/GDAXI, 13013/NDX, 13128/NDX, 13301/GDAXI, all → `*.cash`).**
`QM_MagicSymbolCanonical` canonicalises to the text before the first `.`; there is no
`NDX→US100`, `GDAXI→GER40`, or `WS30→US30` alias (only `USOIL→XTIUSD` exists). These fail
closed **even after a rebuild** — a registry re-symbol question, ROT-class, out of scope
for this census. Same reason additionally applies to **9641/WS30→US30.cash**.

**D — no verified FTMO symbol name on the census target account (3 sleeves: 11132/SP500,
12567/XNGUSD, 13117/EURGBP).** Checked against: the `FTMO_TRIAL` alias venue
(`framework/registry/execution_symbol_aliases_v1.json`, bound to account 1513845506, not
this census's 1514536732), the 2026-09-06 native capture
(`docs/ops/evidence/2026-09-14_ftmo_book_v2/ftmo_book_symbol_cost_snapshot_v2.json`), the
live FTMO ticks/history dirs, and all terminal + Experts logs (`ftmo_symbol_probe.json`).
None of the three names appear in any source.

**E — cross-account alias only, zero on-account corroboration (1 sleeve: 9641/WS30, also
under reason C).** `US30.cash` appears only in the cross-account `FTMO_TRIAL` alias table
(bound to account 1513845506); the registry's own matching rule is
`EXACT_CASE_SENSITIVE_VENUE_ACCOUNT_SERVER_RAW_SYMBOL` with
`cross_venue_pooling_for_qualification=false`, and no ticks dir, history dir, or log line
corroborates it on 1514536732.

**F — dark no-op in v2 (2 sleeves: 12778, 13117), per `BOOK_SPRINT_2026-09-20.md` D7.**
Both are `symbol-input-slot+multi-symbol` cointegration/pair EAs whose second leg is not
FTMO-verified (12778 needs EURJPY; 13117 needs AUDJPY + the already-unverified EURGBP
primary).

## Magic collisions — resolved by the deployment plan, not excluded (correction iii)

Two ADMIT rows reuse a magic currently held by a *different* sha256 on the RUNNING FTMO
demo (AutoTrading ON by OWNER):

| magic | roster binds (sha256[:12]) | live on demo today (sha256[:12]) | chart |
|---:|---|---|---|
| 107060001 | QM5_10706 `01e34b2059de` | `6f290d49defd` | chart02 |
| 114210000 | QM5_11421 `0f7c8ff9ad91` | `4ff02978ae5d` | chart03 |

`magic_collision_resolution=resolved_by_profile_replacement` in the JSON: the v2 profile
replaces the v1 profile wholesale (v1 detached first), so these are not two identities
racing for one magic in practice. The deploy/copy plan must still sequence the detach
before the v2 profile loads — that is a deploy-plan step, not a census gate.

## Governor input deltas — PROPOSAL ONLY (correction iv, do not apply)

Not applied anywhere. Policy `FTMO_2S_P1_100K_V2` and its thresholds are untouched. Both
CSVs derive from the **same** row set — the governor's 8 live magics UNION the 16-row
ADMIT set:

```
allowed_magics_csv    = 15370001,15560004,15670007,104030002,105130003,107000003,
                        107060001,109390001,111650000,111650002,114210000,114210003,
                        114220004,117080000,119100006,125670003,129890003,130540000,
                        132130000,200480000,215050000,414700000
new_magics_to_add_csv = 15560004,15670007,104030002,105130003,107000003,109390001,
                        111650000,111650002,114210003,117080000,125670003,129890003,
                        132130000,414700000
governed_symbols_csv  = AUDCAD,AUDUSD,EURUSD,GBPUSD,NZDUSD,USDCAD,USDJPY,USOIL.cash,
                        XAGUSD,XAUUSD
```

(`15370001` stays in the governor's existing set — it is one of the 8 live magics — even
though `QM5_1537` itself is EXCLUDE here; that magic is currently held by a different
live sleeve on the demo, unaffected by this census.)

## Other checks

* **magic formula** `ea_id*10000+slot`: 28/28 rows satisfy it; the only reported registry
  cross-registration in `magic_numbers.csv` would be flagged as `reg_collision` — none
  present.
* **RISK_PERCENT (e)**: re-derived for all 28 rows from the analytic manifest
  (`weight_risk_percent` for existing sleeves, `burn_in_risk_percent` for new ones) and
  reconciled against the profile manifest's chart `risk_percent`: 0 mismatches
  (tolerance 5e-5).
* **News capability (c)**: recorded, never an exclude reason (demo burn-in). 27/28
  sources declare `input QM_NewsComplianceProfile qm_news_compliance` (FTMO mode 2
  selectable); `QM5_1567` has no news input at all — admitted here on symbol/magic/risk
  grounds, but the deploy/copy plan should record that 1567 cannot enforce the FTMO news
  blackout in-EA.
* **`symbol_handling_class`** is a source-file scan heuristic
  (`tools/strategy_farm/ea_symbol_literal_inventory.py` over the tip `.mq5`/`.mqh`), not
  a property read out of the binary — recorded as such per row in
  `symbol_handling_detail`.

## Open items carried forward from the slot-1 base (unaffected by this merge)

1. Index sleeves (reason C) need a registry re-symbol or an alias-aware resolver to be
   deployable on FTMO at all — this is FX + metals + oil territory as things stand,
   unless OWNER opens a registry re-symbol (ROT-class) for GDAXI/NDX/WS30.
2. `QM5_1537`'s DXZ preset value for `strategy_calendar_symbol` is not recorded anywhere
   this census can read.
3. Is `governed_symbols_csv` a coverage gate for governed flattening? If yes, any pruning
   asymmetry vs `allowed_magics_csv` is live-account exposure, not a formatting nit.

## Blockers / caveats

1. **3 unverified symbols** (SP500, XNGUSD, EURGBP): to admit later, capture the real
   FTMO name read-only (Market Watch add + native `SymbolInfo` read, or a fill receipt) —
   do not guess `US500.cash`/`NGAS.cash`.
2. **News-capability + symbol-handling class are source-derived** (the sha-bound binary's
   build provenance is its identity; current tip source is the reference). No binary was
   recompiled to confirm a wired input.
3. This census decides admission only; it does not build the profile/copy plan or touch
   the governor. Both are separate, later steps per `BOOK_SPRINT_2026-09-20.md` F4.
