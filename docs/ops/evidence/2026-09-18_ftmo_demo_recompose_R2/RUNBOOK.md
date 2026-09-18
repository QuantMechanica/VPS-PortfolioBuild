# RUNBOOK — FTMO Demo recomposition to `R2_capped` (operator: Fable)

**DO NOT START THIS RUNBOOK YET.** Phase 0 gates it and Phase 0 is currently **RED**:
three of eight sleeves are dark-on-venue (`PACKAGE.md` §4 B1) and the governor allow-list
does not cover the roster (B2). Steps 1-3 of Phase 0 are the work that is actually ready
to do today; everything from Phase 1 onward is written so that it is executable the moment
Phase 0 goes green, and not before.

Conventions: every command runs from `C:\QM\repo` unless stated. `⟂` marks a **readback** —
do not proceed until its expected value is observed. Paths are absolute on purpose.

---

## Phase 0 — Gates (must ALL be green before anything is written)

| # | gate | state today | who |
|--:|---|---|---|
| 0.1 | OWNER has selected `R2_capped` in writing (roster selection is ROT) | **OPEN** | OWNER |
| 0.2 | B1 resolved: no sleeve is dark on its venue symbol (`PACKAGE.md` §4 B1) | **RED — 3 sleeves** | Fable → OWNER decision among the 3 options in B1 |
| 0.3 | B2 resolved: governor preset + pinned sha updated and committed | **RED** | Codex (see `GAPS.md` G3) |
| 0.4 | B3 resolved: `demo_install.py` generalised, or a documented manual staging path signed off | **RED** | Codex (`GAPS.md` G1) |
| 0.5 | A decision record exists at `decisions/2026-09-__ _ftmo_demo_recompose_r2.md` | OPEN | Fable, after 0.1 |
| 0.6 | An `agent_tasks` row exists with exactly one assignee for the execution | OPEN | Fable |

> **If 0.2 is resolved by dropping or substituting sleeves, STOP and re-run the
> first-passage engine.** The R2 numbers (E2E 0.9223, LCB 0.9059, median 288 bd) are
> properties of *these eight streams*. A 5-sleeve or substituted roster is a different
> roster and must be re-priced before it goes in front of OWNER.

---

## Phase 1 — Pre-flight (read-only, safe to run now)

**1.1 Re-derive the facts and confirm nothing drifted since 2026-09-18.**

```
python docs\ops\evidence\2026-09-18_ftmo_demo_recompose_R2\gather_facts.py
```

⟂ prints `{"sleeves": 8, …}` and exits 0. Any `Refusal`/traceback = a seal, setfile or
binary moved; stop and re-audit.

**1.2 Re-derive the presets and confirm byte-stability.**

```
Remove-Item -Recurse -Force docs\ops\evidence\2026-09-18_ftmo_demo_recompose_R2\sets
python docs\ops\evidence\2026-09-18_ftmo_demo_recompose_R2\build_sets.py
```

⟂ `manifest_sha256 == b18876a6e847a97772835ff2047c8463627e8c9d818b97a856fd08a1d4f38f5a`.
A different value means an upstream sealed baseline changed — re-open `PACKAGE.md` §1.3
before continuing.

**1.3 Confirm the live profile is still the one this plan was written against.**

```
python -c "import sys; sys.path.insert(0,'.'); from tools.strategy_farm.ftmo import demo_cycle as dc; from pathlib import Path; T=Path(r'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850'); r=dc.parse_chart_profile(T/'MQL5/Profiles/Charts/Default', T/'MQL5/Experts/QM_FTMO'); print(len(r), dc.roster_hash(r))"
```

⟂ `8 6c5383d8777728ba17abd1a836858b9db87c306d2931445ac642762075ac9bf2`.
A different hash means someone changed the demo since this package was built — re-read
`CHART_PLAN.md` §1 against reality before proceeding.

**1.4 Confirm the account identity.**

```
python -c "import configparser; p=configparser.ConfigParser(); p.read(r'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\config\common.ini', encoding='utf-16'); print(p.get('Common','Login',fallback=''), p.get('Common','Server',fallback=''), p.get('Experts','Enabled',fallback='?'))"
```

⟂ `1514536732 FTMO-Demo <flag>`. Login/server must match exactly. Note the `Experts`
flag — `demo_install.py` refuses unless it is `0`; see step 2.1.

---

## Phase 2 — Quiesce (OWNER actions)

**2.1 OWNER turns AutoTrading OFF** in the FTMO terminal UI.
⟂ re-run 1.4; `Experts.Enabled` reads `0`.
*No AI seat performs this step. If it is not done, stop — writing a chart profile under a
live AutoTrading session risks a partially-applied roster trading real signals.*

**2.2 OWNER closes the FTMO terminal.**
⟂ no `terminal64.exe` process remains whose image path is under
`C:\Program Files\FTMO Global Markets MT5 Terminal`.
*Select by path. Never kill terminals under `D:\QM\mt5\T1..T10` or `C:\QM\mt5\T_Live`.*

---

## Phase 3 — Backup (must complete before any write)

**3.1** Run the three `Copy-Item -Recurse` commands in `CHART_PLAN.md` §5 plus the
`ftmo_demo_cycle.json` copy.

**3.2** Write `D:\QM\reports\ftmo_trial\backup_20260918\backup_manifest.json` with
path + sha256 + bytes per file.

⟂ 12 chart-profile files (11 `.chr` + `order.wnd`), 12 presets, 10 `.ex5`.
⟂ Spot-verify: re-hash three restored-from-backup files and compare to the live originals.

**Stop condition:** if the backup count does not match, do not proceed. A recomposition
without a verified backup has no rollback.

---

## Phase 4 — Stage binaries and presets

**4.1** Copy the 7 binaries listed in `CHART_PLAN.md` §2 from
`C:\QM\repo\framework\EAs\<label>\<label>.ex5` into
`…\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Experts\QM_FTMO\`.
Copy atomically (temp name → verify sha → `os.replace`), the way
`demo_install.atomic_copy` does. Back up any destination that exists with a different sha
into a **new dated folder**, e.g. `_pre_r2_20260918\`, never into `_pre_m13_20260906\`.

⟂ `Get-FileHash` each of the 8 sleeve binaries; all match `PACKAGE.md` §1.3.

**4.2** Copy the 8 `.set` files from
`docs\ops\evidence\2026-09-18_ftmo_demo_recompose_R2\sets\` into
`…\MQL5\Profiles\Presets\QM_FTMO_M13\`.

⟂ `Get-FileHash` each; all match `sets/manifest.json` `output_sha256`.

**4.3** Install the revised governor preset (`CHART_PLAN.md` §3.1) and revised telemetry
preset (§3.3).

⟂ the governor preset's sha matches `governor.active_preset_sha256` in
`tools\strategy_farm\config\ftmo_m13_standard_demo.v1.json`. Verify by running the
binding loader, which is the same check the set-derivation path performs:

```
python -c "import sys; sys.path.insert(0,'.'); from tools.strategy_farm.ftmo import trial_setpath as t; b,r,p,_=t.load_binding(); print('binding_ok', b['binding_id'], r['rulepack_id'])"
```

⟂ prints `binding_ok …`. A `Refusal` here (`active_preset_hash_drift`,
`rulepack_file_hash_drift`, …) means 4.3 and the repo are out of step — fix before Phase 5.

**4.4** Create the new telemetry output directories:
`…\MQL5\Files\QM\ftmo_trial\<new date>\` and `D:\QM\reports\ftmo_trial\<new date>\`.

---

## Phase 5 — Chart profile

**5.1** Write the 9 chart files per `CHART_PLAN.md` §2 (charts 01-09). Keep `chart10`,
`chart11` and `order.wnd` as they are — the file set and count do not change, so `order.wnd`
stays valid.

Each edited `.chr` must be written **UTF-16 with BOM**, matching the existing files. Verify
before moving on: a UTF-8 chart file is silently unreadable to MT5 and
`demo_cycle._read_chart_text` will fall back to a replacement-character decode that *looks*
like it parsed.

⟂ each file starts with `\xff\xfe` and re-reads as UTF-16 without replacement characters.

**5.2** Parse the result read-only:

```
python -c "import sys; sys.path.insert(0,'.'); from tools.strategy_farm.ftmo import demo_cycle as dc; from pathlib import Path; T=Path(r'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850'); r=dc.parse_chart_profile(T/'MQL5/Profiles/Charts/Default', T/'MQL5/Experts/QM_FTMO'); [print(s['chart'], s['ea_id'], s['symbol'], s['magic'], s['risk_pct'], s['ex5_sha'][:12]) for s in r]; print('n=',len(r),'hash=',dc.roster_hash(r),'risk=',sum(s['risk_pct'] for s in r))"
```

⟂ `n= 8`; the magic set is exactly
`{101450034, 107000003, 107060001, 114220004, 116600004, 127100000, 132130000, 202660000}`;
`risk= 2.5`; every `ex5_sha` matches `PACKAGE.md` §1.3; `hash` ≠ `6c5383d877…`.
**Record the new hash** — it is the roster identity for the whole cycle.

**5.3** Check the timeframes by eye (the parser does not):

```
python -c "from pathlib import Path; d=Path(r'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Profiles\Charts\Default'); [print(c.name, [l for l in c.read_bytes().decode('utf-16').splitlines() if l.startswith(('symbol=','period_type=','period_size='))]) for c in sorted(d.glob('chart*.chr'))]"
```

⟂ matches `CHART_PLAN.md` §2 (`period_type`/`period_size`: H1 = 1/1, H4 = 1/4, D1 = 2/1).

**Stop condition:** any mismatch in 5.2 or 5.3 → roll back per `CHART_PLAN.md` §6 rather
than patching in place. A half-correct profile is the failure mode that produces
uninterpretable demo evidence.

---

## Phase 6 — Bring up and observe (OWNER gate)

**6.1 OWNER starts the FTMO terminal.** AutoTrading stays **OFF** for this step.

**6.2** Read the per-EA logs after init settles:

```
python -c "from pathlib import Path; d=Path(r'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Files\QM'); import re; [print(ea, sorted(set(re.findall(r'\"event\":\"([A-Z_]+)\"', p.read_bytes().replace(b'\x00',b'').decode('utf-8','replace'))))) for ea in (13213,10706,10700,11660,11422,10145,20266,12710) for p in [d/('QM5_%d_ea-%d.log'%(ea,ea))] if p.is_file()]"
```

⟂ every sleeve shows `SYMBOL_GUARD_INIT`, `NEWS_CALENDAR_LOADED`, `KILL_SWITCH_INIT`,
`INIT_OK`.
⟂ **zero** `FRAMEWORK_INIT_FAILED`, `EA_MAGIC_RESOLUTION_FAILED`, `EA_MAGIC_NOT_REGISTERED`,
`EA_MAGIC_COLLISION_DETECTED` across all eight.
⟂ each `SYMBOL_GUARD_INIT` payload carries the **bare venue symbol** (`USDJPY`,
`US100.cash`, …), not a `.DWX` name.

**6.3** Build the cycle ledger:

```
python tools\strategy_farm\ftmo\demo_cycle.py build
```

⟂ `state: "NEW"`, `sleeve_count: 8`, `roster_hash` == the value recorded in 5.2,
`cycle_start_utc` = now, `is_new_cycle_this_observation: true`.

**6.4** Read the `ftmo_trial_pulse` read-model.
⟂ `RUNNING`, clock fresh, bound to the new trial id.

**6.5 OWNER — and only OWNER — enables AutoTrading.**

**6.6** After the first full session per timeframe (≥1 completed H1 bar for 13213/10706/10700,
≥1 completed H4 bar for 11660, ≥1 completed D1 bar for 11422/10145/20266/12710), re-run the
log census from 6.2 and look specifically for `TM_OPEN` / `ENTRY_ACCEPTED`.

⟂ **Any sleeve showing `INIT_OK` with zero `TM_OPEN` after its first eligible bar is the
B1 dark-sleeve failure.** Escalate immediately; do not "give it more time". The signature
is exactly what `QM5_20048` shows on the current book today.

**6.7** Record the receipt at
`docs\ops\evidence\2026-09-18_ftmo_demo_recompose_R2\install_receipt.json`
(shape: `qm.ftmo-demo-install/v1`, see the 2026-09-06 receipt) with `inventory_before`,
`backups`, `installed`, `inventory_after`, the old and new `roster_hash`, the new
`cycle_start_utc`, and explicit `autotrading_changed` / `charts_changed` /
`tlive_written` flags. Then write the decision record from gate 0.5.

---

## Stop conditions (abort and roll back per `CHART_PLAN.md` §6)

1. **OWNER has not selected `R2_capped` in writing.** Roster selection is ROT.
2. **Any B1 sleeve is still literal-gated.** Deploying knowingly-dark sleeves manufactures
   invalid validation evidence — worse than not deploying.
3. **Backup incomplete or unverified** (Phase 3 counts wrong, or a spot-check hash differs).
4. **AutoTrading is still ON** at Phase 3+, or the terminal is still running at Phase 4+.
5. **`load_binding()` refuses** at 4.3 — the repo and the staged governor preset disagree.
6. **Staged sha ≠ expected sha** anywhere in 4.1 / 4.2.
7. **`parse_chart_profile` returns ≠ 8 sleeves**, a wrong magic, `risk ≠ 2.5`, or an
   `ex5_sha` that is not in `PACKAGE.md` §1.3.
8. **Any `FRAMEWORK_INIT_FAILED` or `EA_MAGIC_*` failure** in 6.2.
9. **A sleeve initialises but does not trade** after its first eligible bar (6.6).
10. **Any instruction to toggle AutoTrading, touch `T_Live`, touch `D:\QM\mt5\T1..T10`, or
    write the farm SQLite DB.** Refuse and route to OWNER. AutoTrading on any terminal is
    OWNER-only, without exception.
11. **A VPS reboot is proposed** as a fix. It stops T_Live live trading. It is not a
    remedy for anything in this runbook.
