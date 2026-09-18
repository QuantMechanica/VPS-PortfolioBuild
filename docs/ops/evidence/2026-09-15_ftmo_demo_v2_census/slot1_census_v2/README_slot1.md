# FTMO demo book v2 admission census — slot-1 v2 rework (ticket 42a437a4, book sprint F4)

Status: **REVIEW — not committed, not applied.** Read-only census only.
Binding due: **Wed 2026-09-16 18:00Z** (ticket 42a437a4 title).

**Superseded 2026-09-18**: the orchestrator's RECYCLE close used THIS directory's census
as the merge base and applied corrections (i)–(v) on top (see `../README.md`, section
"Corrections applied to the slot-1 base"). Result: 16 ADMIT / 12 EXCLUDE, canonical at
`../roster_ftmo_demo_v2.json`. This directory's own 1/16/11 split is preserved unmodified
for the record — do not re-run it as if it were still current.

> **Session collision.** This directory holds the slot-1 output of a 3-session
> `run_agent_orchestration_task.py --agent claude --max-sessions 3` fan-out in which two
> sessions were handed the same ticket by the same generic prompt. The sibling session owns
> `tools/strategy_farm/ftmo_demo_v2_census.py` and `../roster_ftmo_demo_v2.json` /
> `../README.md`; this slot-1 work is preserved here untouched so neither side is lost.
> See `COLLISION.md`. **Neither side is committed.** OWNER/reviewer picks one, or merges.

## 1. Result

| | v1 (rejected) | slot-1 v2 |
|---|---:|---:|
| sleeves | 28 | 28 |
| ADMIT (deployable today) | 24 | **1** |
| ADMIT_CONDITIONAL (needs a named precondition first) | — | **16** |
| EXCLUDE | 4 | **11** |

**The headline is not "24 sleeves are ready". It is: exactly one roster sleeve (QM5_41470,
USDJPY) can be attached to the FTMO demo as-is.** Every other sleeve carries at least one
concrete, evidence-bound blocker. The v1 census reported 24/4 because it never checked binary
vintage, never implemented its own `.DWX`-literal rule, and treated a cross-account alias table
as authoritative.

### Decision vocabulary

* **ADMIT** — the bound binary can attach and resolve its magic on this account today.
* **ADMIT_CONDITIONAL** — nothing disqualifies the *sleeve*, but the *artifact* needs a named,
  listed precondition (artifact-only rebuild, or detaching a live chart) before it can attach.
  This is a deploy-plan input, not a pass.
* **EXCLUDE** — do not carry into the burn-in.

`admit_now` (bool) in the JSON is the strict ADMIT-only reading if a consumer needs a binary flag.

## 2. Roster

| # | EA | DXZ symbol | FTMO symbol | symbol source / on-account corroboration | binary (location, sha256[:12], built UTC) | resolver fix | canonical match | handling class | news | slot | magic | collision | risk % | decision |
|---:|---|---|---|---|---|:--:|:--:|---|---|---:|---:|:--:|---:|---|
| 1 | QM5_41470 | USDJPY.DWX | USDJPY | alias (x-account) / ticks+history | repair_v2, `ef34638d26eb`, 2026-09-13 | yes | yes | symbol-input-slot | mode 2 | 0 | 414700000 | no | 0.5904 | **ADMIT** |
| 2 | QM5_1556 | XAUUSD.DWX | XAUUSD | alias (x-account) / ticks+history+log | T_Live, `9371a8a03008`, 2026-07-13 | **NO** | yes | chart-symbol-only+non-chart-reads | mode 2 | 4 | 15560004 | no | 0.5407 | **ADMIT_CONDITIONAL** |
| 3 | QM5_1567 | EURUSD.DWX | EURUSD | native capture / ticks+history | T_Live, `71c2f84b3e69`, 2026-07-15 | **NO** | yes | chart-symbol-only | none | 7 | 15670007 | no | 0.1848 | **ADMIT_CONDITIONAL** |
| 4 | QM5_10403 | XAUUSD.DWX | XAUUSD | alias (x-account) / ticks+history+log | T_Live, `b6c194d928b6`, 2026-07-13 | **NO** | yes | chart-symbol-only | mode 2 | 2 | 104030002 | no | 0.2179 | **ADMIT_CONDITIONAL** |
| 5 | QM5_10513 | XAUUSD.DWX | XAUUSD | alias (x-account) / ticks+history+log | T_Live, `04b62af28c64`, 2026-07-13 | **NO** | yes | chart-symbol-only | mode 2 | 3 | 105130003 | no | 0.2987 | **ADMIT_CONDITIONAL** |
| 6 | QM5_10700 | XAUUSD.DWX | XAUUSD | alias (x-account) / ticks+history+log | deploy_staging, `5fbf2ba00482`, 2026-09-03 | **NO** | yes | chart-symbol-only | mode 2 | 3 | 107000003 | no | 0.0130 | **ADMIT_CONDITIONAL** |
| 7 | QM5_10706 | GBPUSD.DWX | GBPUSD | alias (x-account) / ticks+history | T_Live, `01e34b2059de`, 2026-07-13 | **NO** | yes | chart-symbol-only | mode 2 | 1 | 107060001 | **YES** | 0.0527 | **ADMIT_CONDITIONAL** |
| 8 | QM5_10919 | XTIUSD.DWX | USOIL.cash | alias (x-account) / ticks+history+log | T_Live, `57e0db840161`, 2026-07-31 | **NO** | yes | chart-symbol-only | mode 2 | 1 | 109190001 | no | 0.8578 | **ADMIT_CONDITIONAL** |
| 9 | QM5_10939 | GBPUSD.DWX | GBPUSD | alias (x-account) / ticks+history | T_Live, `308604a3546c`, 2026-07-31 | **NO** | yes | chart-symbol-only | mode 2 | 1 | 109390001 | no | 0.1958 | **ADMIT_CONDITIONAL** |
| 10 | QM5_11165 | AUDCAD.DWX | AUDCAD | ticks dir / ticks | T_Live, `8f6d33a3dfb0`, 2026-07-17 | **NO** | yes | chart-symbol-only | mode 2 | 2 | 111650002 | no | 0.5082 | **ADMIT_CONDITIONAL** |
| 11 | QM5_11165 | EURUSD.DWX | EURUSD | native capture / ticks+history | T_Live, `8f6d33a3dfb0`, 2026-07-17 | **NO** | yes | chart-symbol-only | mode 2 | 0 | 111650000 | no | 0.4097 | **ADMIT_CONDITIONAL** |
| 12 | QM5_11421 | AUDUSD.DWX | AUDUSD | ticks dir / ticks | T_Live, `0f7c8ff9ad91`, 2026-07-31 | **NO** | yes | chart-symbol-only | mode 2 | 3 | 114210003 | no | 0.3213 | **ADMIT_CONDITIONAL** |
| 13 | QM5_11421 | EURUSD.DWX | EURUSD | native capture / ticks+history | T_Live, `0f7c8ff9ad91`, 2026-07-31 | **NO** | yes | chart-symbol-only | mode 2 | 0 | 114210000 | **YES** | 0.3247 | **ADMIT_CONDITIONAL** |
| 14 | QM5_11708 | EURUSD.DWX | EURUSD | native capture / ticks+history | T_Live, `de06fb032c9b`, 2026-07-13 | **NO** | yes | chart-symbol-only | mode 2 | 0 | 117080000 | no | 0.5449 | **ADMIT_CONDITIONAL** |
| 15 | QM5_12567 | XAUUSD.DWX | XAUUSD | alias (x-account) / ticks+history+log | T_Live, `5d5be334288e`, 2026-07-31 | **NO** | yes | chart-symbol-only | mode 2 | 3 | 125670003 | no | 0.7848 | **ADMIT_CONDITIONAL** |
| 16 | QM5_12989 | XAUUSD.DWX | XAUUSD | alias (x-account) / ticks+history+log | T_Live, `7f2c298f4a8b`, 2026-07-31 | **NO** | yes | chart-symbol-only | mode 2 | 3 | 129890003 | no | 0.2275 | **ADMIT_CONDITIONAL** |
| 17 | QM5_13213 | USDJPY.DWX | USDJPY | alias (x-account) / ticks+history | T_Live, `321b1dca0064`, 2026-07-14 | **NO** | yes | chart-symbol-only | mode 2 | 0 | 132130000 | no | 0.0443 | **ADMIT_CONDITIONAL** |
| 18 | QM5_1537 | XAGUSD.DWX | XAGUSD | native capture / ticks+history+log | deploy_staging, `142a019e773a`, 2026-08-16 | **NO** | yes | chart-symbol-only | mode 2 | 1 | 15370001 | **YES** | 0.0769 | **EXCLUDE** |
| 19 | QM5_9641 | WS30.DWX | US30.cash | alias (x-account) / **none** | deploy_staging, `21eda8527f66`, 2026-08-11 | **NO** | **NO** | chart-symbol-only | mode 2 | 2 | 96410002 | no | 0.0104 | **EXCLUDE** |
| 20 | QM5_10440 | NDX.DWX | US100.cash | alias (x-account) / ticks+history+log | T_Live, `b71d302997ec`, 2026-06-28 | **NO** | **NO** | chart-symbol-only | mode 2 | 3 | 104400003 | no | 0.0584 | **EXCLUDE** |
| 21 | QM5_10911 | GDAXI.DWX | GER40.cash | alias (x-account) / ticks+history+log | T_Live, `a815c73da991`, 2026-07-31 | **NO** | **NO** | chart-symbol-only | mode 2 | 3 | 109110003 | no | 0.1260 | **EXCLUDE** |
| 22 | QM5_11132 | SP500.DWX | UNVERIFIED | unverified / **none** | T_Live, `25b68c44d972`, 2026-07-31 | **NO** | **NO** | chart-symbol-only | mode 2 | 0 | 111320000 | no | 0.4272 | **EXCLUDE** |
| 23 | QM5_12567 | XNGUSD.DWX | UNVERIFIED | unverified / **none** | T_Live, `5d5be334288e`, 2026-07-31 | **NO** | **NO** | chart-symbol-only | mode 2 | 2 | 125670002 | no | 0.9577 | **EXCLUDE** |
| 24 | QM5_12778 | AUDUSD.DWX | AUDUSD | ticks dir / ticks | T_Live, `2c4707060169`, 2026-07-13 | **NO** | yes | symbol-input-slot+multi-symbol | mode 2 | 0 | 127780000 | no | 0.4393 | **EXCLUDE** |
| 25 | QM5_13013 | NDX.DWX | US100.cash | alias (x-account) / ticks+history+log | deploy_staging, `bf2cc2ecaff8`, 2026-08-02 | **NO** | **NO** | chart-symbol-only | mode 2 | 0 | 130130000 | no | 0.0105 | **EXCLUDE** |
| 26 | QM5_13117 | EURGBP.DWX | UNVERIFIED | unverified / **none** | T_Live, `adfa1ba617a8`, 2026-07-14 | **NO** | **NO** | symbol-input-slot+multi-symbol | mode 2 | 0 | 131170000 | no | 0.4100 | **EXCLUDE** |
| 27 | QM5_13128 | NDX.DWX | US100.cash | alias (x-account) / ticks+history+log | T_Live, `364867a9fe8d`, 2026-07-13 | **NO** | **NO** | chart-symbol-only | mode 2 | 0 | 131280000 | no | 1.1028 | **EXCLUDE** |
| 28 | QM5_13301 | GDAXI.DWX | GER40.cash | alias (x-account) / ticks+history+log | T_Live, `d7f10a684bdb`, 2026-07-16 | **NO** | **NO** | chart-symbol-only | mode 2 | 10 | 133010010 | no | 0.0648 | **EXCLUDE** |

Regenerate this table from the JSON at any time; `_table.md` holds the same rows.

## 3. The four blocker classes

### 3.1 Pre-fix binaries — 27 of 28 rows [F1, F7]

The FTMO magic resolver only tolerates the registry's `.DWX` suffix from commit
`4fb47bd3b5` (2026-09-06 19:56:06Z, `framework/include/QM/QM_MagicResolver.mqh`). The fix
lives in a framework include, so it is present only in binaries compiled after that moment.

**27 of 28 bound binaries predate it** (mtimes 2026-06-28 … 2026-09-03). Only `QM5_41470`
(repair_v2, built 2026-09-13) contains it. Directly observed consequence, FTMO demo Experts log
`MQL5/Logs/20260906.log` (UTF-16LE):

```
21:42:47.908  QM5_10706_tv-mon-ls (GBPUSD,H1)    EA_MAGIC_RESOLUTION_FAILED: ea_id=10706 slot=1 registered_symbol=GBPUSD.DWX expected_symbol=GBPUSD magic=107060001
21:44:02.471  QM5_11910_...-d1    (NZDUSD,Daily) EA_MAGIC_RESOLUTION_FAILED: ea_id=11910 slot=6 registered_symbol=NZDUSD.DWX expected_symbol=NZDUSD magic=119100006
21:45:36.633  QM5_21505_xag-...   (XAGUSD,D1)    EA_MAGIC_RESOLUTION_FAILED: ea_id=21505 slot=0 registered_symbol=XAGUSD.DWX expected_symbol=XAGUSD magic=215050000
```

`QM_Common.mqh:273-280` turns that `-1` into `FRAMEWORK_INIT_FAILED` — the chart does not trade.
The journal `logs/20260906.log` shows the matching `initializing of ... failed with code 1` lines.

This is what v1's caveat 4 ("sha-bound, no rebuild") silently assumed away: the roster binds
binaries that **cannot** attach to broker-named charts. The repair is an artifact-only rebuild
(the route the 2026-09-06 receipts document), which is OWNER's rebuild decision, not something
this census performs.

**Stated limitation, and it cuts against my own predicate:** the 2026-09-06 journal records
`QM5_11421` (registry `EURUSD.DWX`, chart `EURUSD`) at 21:43:02 and `QM5_11422`
(`USDCAD.DWX` / `USDCAD`) at 21:43:25 as *loaded successfully* with no init failure — i.e.
**before** the 21:56 fix, with the same registry-vs-broker mismatch that killed 10706/11910/21505.
The Experts log for that day survives only as 18 lines, so the mechanism cannot be read out. The
vintage predicate is therefore applied as a **necessary condition that may over-flag**, not as a
proven sufficient one. Over-flagging costs a rebuild decision; under-flagging costs a silent
non-attach on a burn-in book — so the conservative direction is the right one. See Q1.

### 3.2 Symbol names that cannot resolve even after a rebuild — 6 rows [new in v2]

`QM_MagicSymbolCanonical` (`QM_MagicResolver.mqh:134`) canonicalises a symbol to the text before
the first `.`, plus exactly one broker alias (`USOIL` → `XTIUSD`). So the post-fix comparison is
still a **base-name** comparison:

| registry | FTMO chart | canonical pair | resolves? |
|---|---|---|---|
| `XTIUSD.DWX` | `USOIL.cash` | XTIUSD / XTIUSD | yes (explicit alias) |
| `XAUUSD.DWX` | `XAUUSD` | XAUUSD / XAUUSD | yes |
| `NDX.DWX` | `US100.cash` | NDX / **US100** | **no** |
| `GDAXI.DWX` | `GER40.cash` | GDAXI / **GER40** | **no** |
| `WS30.DWX` | `US30.cash` | WS30 / **US30** | **no** |
| `SP500.DWX` | `US500.cash`? | SP500 / **US500** | **no** |

Every index sleeve therefore fails closed on FTMO **regardless of a rebuild**. That is a registry
re-symbol question (ROT-class: registry / candidate-pool semantics), not a compile question. v1
admitted all of these. Affected: QM5_9641, QM5_10440, QM5_10911, QM5_13013, QM5_13128, QM5_13301.

### 3.3 Symbols with no evidence on the target account — 3 rows [F5, F6]

The `FTMO_TRIAL` alias venue in `framework/registry/execution_symbol_aliases_v1.json` is bound to
**account 1513845506**, not to the census target **1514536732**, and the registry's own rules are
`matching = EXACT_CASE_SENSITIVE_VENUE_ACCOUNT_SERVER_RAW_SYMBOL` and
`cross_venue_pooling_for_qualification = false`. v1 called it "authoritative" for 1514536732 and
used its *silence* as proof of absence. In v2 an alias hit is `symbol_source =
alias_registry_FTMO_TRIAL_cross_account` and only counts as verified once corroborated on the
target account.

The probe (`ftmo_symbol_probe_slot1.json`, regenerated on every run) reads three sources:

* `bases/FTMO-Demo/symbols/` — **`symbols.raw` does not exist** on this MT5 build. The files are
  `symbols-<login>.dat` / `selected-<login>.dat` (6 files, three logins). A printable-token scan
  of `symbols-1514536732.dat` (86,016 bytes, 1,077 distinct tokens) returns **0 probe-name hits** —
  the file is not plaintext, so its silence is not evidence either. v1 asserted this without
  recording a scan; the scan output is now in the probe JSON.
* `bases/FTMO-Demo/ticks/` — 27 symbols; `bases/FTMO-Demo/history/` — 11 symbols.
* **75 terminal + Experts logs**, UTF-16LE decoded (v1 never read them). Probe-name occurrences:
  `{"GER40.cash": 137, "US100.cash": 342, "USOIL.cash": 100, "XAGUSD": 48, "XAGUSD.DWX": 1, "XAUUSD": 776}`.

Result: `US500`, `SP500`, `NGAS`, `XNGUSD`, `EURGBP`, `US30` appear in **none** of the three
sources. The EXCLUDE reason is now the accurate one ("not in ticks, not in history, not in 75
logs; symbol DB not plaintext") instead of "no read-only source exists".

Notably `US30.cash` (QM5_9641) *is* in the cross-account alias table but has **zero**
corroboration on 1514536732 — no ticks dir, no history dir, no log line. v1 admitted it on the
alias alone.

### 3.4 Magics held by a different live binary — 3 rows [F2]

The FTMO demo is `RUNNING (AutoTrading ON by OWNER)` with 8 governed sleeves
(`docs/ops/evidence/2026-09-06_ftmo_demo_governor_manifest.md`, parsed — not hardcoded [F10]).
Three roster rows reuse a magic **currently held by a binary with a different sha256**. By the
census's own identity rule (a rebuilt `.ex5` is a new identity) that is two EAs on one magic on a
live account, so `magic_collision = true`:

| magic | roster binds | live on demo | chart |
|---:|---|---|---|
| 15370001 | QM5_1537 `142a019e773a` | `16d66a0f7b86` | chart08 |
| 107060001 | QM5_10706 `01e34b2059de` | `6f290d49defd` | chart02 |
| 114210000 | QM5_11421 `0f7c8ff9ad91` | `4ff02978ae5d` | chart03 |

The deploy plan must **detach those charts before the new profile loads**; that is emitted as an
explicit `detach_required` condition per row and in the JSON's `deploy_preconditions`. The census
does not assume it. v1 computed `gov_overlap` and then deliberately discarded it as "consistency,
not collision".

## 4. Governor input deltas — PROPOSAL ONLY [F4]

Not applied anywhere. Policy `FTMO_2S_P1_100K_V2` and its thresholds are untouched. Both CSVs
derive from the **same** row set — the governor's 8 live magics UNION the deployable rows — so
magic coverage and symbol coverage cannot drift apart. (v1 kept magics 114220004 / 119100006 while
dropping USDCAD / NZDUSD from the symbol CSV, leaving two live sleeves magic-governed but
symbol-ungoverned.)

```
allowed_magics_csv    = 15370001,15560004,15670007,104030002,105130003,107000003,107060001,
                        109190001,109390001,111650000,111650002,114210000,114210003,114220004,
                        117080000,119100006,125670003,129890003,130540000,132130000,200480000,
                        215050000,414700000
new_magics_to_add_csv = 15560004,15670007,104030002,105130003,107000003,109190001,109390001,
                        111650000,111650002,114210003,117080000,125670003,129890003,132130000,
                        414700000
governed_symbols_csv  = AUDCAD,AUDUSD,EURUSD,GBPUSD,NZDUSD,USDCAD,USDJPY,USOIL.cash,XAGUSD,XAUUSD
```

(The JSON holds these as single-line CSVs; the wrapping above is for readability only.)

These are the values for the **deployable** set (ADMIT + ADMIT_CONDITIONAL) and are valid only
once the §3.1 / §3.4 preconditions are met. If OWNER deploys only the strict ADMIT set, the delta
collapses to `new_magics_to_add_csv = 414700000` and `governed_symbols_csv` gains only `USDJPY`.

## 5. Other checks

* **magic formula** `ea_id*10000+slot`: 28/28 rows satisfy it; 0 registry cross-registrations.
* **RISK_PERCENT (e)**: re-derived for **all 28 rows** (not sampled) from the analytic manifest
  (`weight_risk_percent` for existing, `burn_in_risk_percent` for new) and reconciled against the
  profile manifest's chart `risk_percent`: **0 mismatches** (tolerance 5e-5). v1 spot-checked 8.
* **News capability (c)**: recorded, never an exclude reason (demo burn-in). 27/28 sources declare
  `input QM_NewsComplianceProfile qm_news_compliance` (FTMO mode 2 selectable); `QM5_1567` has no
  news input at all. **Derived from the tip `.mq5` source, not from the bound `.ex5`** — where a
  row is flagged `resolver fix = NO` the source↔binary link is known to be broken, so treat the
  figure as source-level. [F7, F11]
* **`symbol_handling_class`** is a **source-file scan heuristic**
  (`ea_symbol_literal_inventory.py` over the tip `.mq5`/`.mqh`), not a property read out of the
  binary. `QM5_1537` classifies as `chart-symbol-only` because its `strategy_calendar_symbol`
  input has an empty default and the classifier requires a literal on the `input string` line —
  recorded rather than papered over. [F11]
* **`.DWX` literal rule (b)** is now *implemented*, not prose [F3]: a `trading_logic_literal` with
  severity `FAIL` always excludes; severity `WARN` excludes unless `(ea_label, path)` is on the
  code-level `LITERAL_INPUT_EXEMPTIONS` allowlist **and** the bound binary postdates the commit
  that added the governing input. `QM5_1537` carries a WARN literal
  (`QM5_1537_MonthlySleeveCalendar.mqh:312`, `XAGUSD.DWX`) whose exemption depends on
  `strategy_calendar_symbol` — added by `dcaeca68f5` at 2026-09-06 20:03:01Z, while the bound
  binary `142a019e…` was built **2026-08-16**. The exemption is refused and 1537 is EXCLUDE. That
  sha is byte-identical to the sealed pre-fix binary refused twice on this account. [F1]

## 6. Open questions / OWNER decisions

1. **Q1 (blocks the rebuild decision):** why did `QM5_11421` / `QM5_11422` load successfully at
   21:43 on 2026-09-06 with pre-fix binaries, when `QM5_10706` / `QM5_11910` / `QM5_21505` failed
   with the same registry-vs-broker mismatch? The Experts log for that day is truncated to 18
   lines. Resolving it decides whether 27 rebuilds are needed or far fewer.
2. **Q2:** index sleeves (§3.2) need a registry re-symbol or an alias-aware resolver to be
   deployable on FTMO at all. Both are ROT-class. Is FTMO demo book v2 an FX + metals + oil book,
   or is a registry change in scope?
3. **Q3:** confirm the §3.4 detach step as an explicit deploy-plan step (the alternative is
   re-slotting those three magics).
4. **Q4:** `QM5_1537`'s DXZ preset value for `strategy_calendar_symbol` is not recorded anywhere
   this census can read; the sealed monthly-sleeve CSV is keyed by the logical `.DWX` name.
5. **Q5:** is `governed_symbols_csv` a coverage gate for governed flattening? If yes, any pruning
   asymmetry vs `allowed_magics_csv` is live-account exposure, not a formatting nit.

## 7. Files

| file | what |
|---|---|
| `ftmo_demo_v2_census_slot1.py` | the re-runnable census (this analysis); writes only into this directory |
| `roster_ftmo_demo_v2_slot1.json` | the census (schema `qm.ftmo-demo-v2-admission-census/v2-slot1`) |
| `ftmo_symbol_probe_slot1.json` | FTMO terminal symbol-inventory probe (ticks, history, symbol-DB scan, 75-log scan) |
| `_table.md` | the §2 table, regenerated from the JSON |
| `COLLISION.md` | the concurrent-session collision record |
| `../README.md`, `../roster_ftmo_demo_v2.json`, `../../..//tools/strategy_farm/ftmo_demo_v2_census.py` | the **sibling session's** concurrent rework — not mine, not reviewed here |
| `../ticket_payload.json` | the ticket payload (pre-existing; the v1 README omitted it from its inventory) [F9] |

Re-run:

```
python -X utf8 docs/ops/evidence/2026-09-15_ftmo_demo_v2_census/slot1_census_v2/ftmo_demo_v2_census_slot1.py
```

## 8. Hard limits honoured

No terminal started, no chart attached, no write into the FTMO or T_Live data dir (FTMO reads are
opens for read only), no recompile, no governor policy change, no gate threshold touched, no
verdict written, no AutoTrading toggle. All writes are inside `slot1_census_v2/`. Nothing
committed.
