# SP-F1 — Q10-Survivor-Matrix verification against state DB

Date: 2026-08-23

Router task: `cb771748-c85d-4819-87c7-98535ab0c047` (`SP-F1`)

## Verdict

PARTIAL — the three live-status claims explicitly quoted in the task's own
`goal` field (13128 "laeuft live", 1556 "bewaehrter Sleeve", 12969
"Kern-Saeule") are independently verified against real DB/registry evidence
below. The full acceptance criterion — a 13-row CSV of the "Blueprint
Section 2 matrix" (Trades/PF/maxDD/Symbol/Assetklasse per EA) compared
against document-claimed values — is **INFRA_BLOCKED**: the source
"blueprint" document is not present anywhere in the canonical checkout
(`docs/`, `decisions/`, `tools/strategy_farm/`) and is very likely a vault
document; `G:\` (the Obsidian vault mount) is not accessible in this session.

## G: drive inaccessible — confirmed this session

```text
$ ls "G:/My Drive"
ls: cannot open directory 'G:/My Drive': Permission denied

PS> Get-ChildItem "G:\My Drive"
Get-ChildItem: Cannot find drive. A drive with the name 'G' does not exist.
```

This is consistent with an already-open standing finding in
`D:\QM\strategy_farm\state\health_alarms.log` (`backup_calendar_continuity`,
2026-08-23T07:32:57Z): "GoogleDriveFS mount absent in this session." It is a
pre-existing environmental condition, not something this task caused, and
not something a headless agent session can remount.

Repo-wide search for a "blueprint" document naming these three EA IDs or a
"Section 2 matrix" found only `docs/ops/QUA-404_PREIMPLEMENTATION_BLUEPRINT_2026-04-28.md`
(2026-04-28, unrelated content — a different blueprint, pre-dates these EA
IDs). No other candidate document exists in the canonical checkout.

## What was actually verified (real DB/registry evidence, no invented values)

Source for live-status: `docs/ops/evidence/2026-08-22_live_sleeve_register_reconciliation_33e46600.csv`
(a same-week, T_Live-derived reconciliation already produced by a prior task;
re-read here, not regenerated). Source for gate history:
`ea_metrics` in `D:\QM\strategy_farm\state\farm_state.sqlite`, queried
read-only this session. Full detail per EA is in the companion CSV
(`docs/ops/evidence/2026-08-23_sp_f1_q10_survivor_matrix_verification.csv`).

- **QM5_13128 / NDX.DWX ("laeuft live")** — **CONFIRMED, with caveat.**
  `manifest_member=yes`, `preset_loaded_24=yes`, live journal event as
  recently as `2026-08-21T17:59:56Z`. Deployment is real. But its
  classification in the reconciliation is
  `LIVE_MANIFEST_Q12_EVIDENCE_STALE` — the Q09 portfolio evidence that
  justified its admission was downgraded stale on 2026-07-18. Best DB
  verdict: Q08 PASS, 57 trades, PF 2.29 (2026-08-18).
- **QM5_1556 / XAUUSD.DWX ("bewaehrter Sleeve")** — **CONFIRMED (live
  activity), unverifiable numerically.** `manifest_member=yes`,
  `preset_loaded_24=yes`, 5 entries accepted in the 2026-08-22 snapshot
  window, classification `LIVE_MANIFEST_REGISTERED` (no discrepancy). But
  `ea_metrics` has no populated trades/PF/maxDD row for this EA on
  XAUUSD.DWX past Q02-Q07 (all numeric fields null in the most recent rows)
  — the "bewaehrt" (proven) characterization cannot be corroborated with a
  numeric Q08/Q09/Q10 record from this DB for this exact symbol; only the
  fact of live deployment is corroborated.
- **QM5_12969 / USDJPY.DWX ("Kern-Saeule")** — **CONFIRMED (live
  deployment), contradicted (gate cleanliness).** `manifest_member=yes`,
  `preset_loaded_24=yes`, classification `LIVE_MANIFEST_REGISTERED` (no
  discrepancy) — live deployment is real. But its own Q08 verdict (the hard
  real-evidence gate) in `ea_metrics` is **`FAIL_SOFT`**, not PASS (300
  trades, PF 1.55, latest extraction 2026-08-18T12:35:32Z). Q09_PORTFOLIO
  (`PASS_PORTFOLIO`, 331 trades, PF 1.4962, maxDD 0.307%) and Q10 (`PASS`,
  331 trades, PF 1.54, maxDD 2.016%) did clear. If "Kern-Saeule" implies
  clean gate history, that is not supported by the Q08 row.

## What is not delivered this pass

- The remaining 10 of 13 EA IDs the blueprint presumably names — unknown,
  since the document could not be read.
- Asset-class field per EA — not attempted without the document's own
  classification scheme.
- A formal match/mismatch flag against document-claimed Trades/PF/maxDD
  numbers — there are no document values to compare against.

## Focused verification

```text
grep -n "Blueprint" docs/ops/QUA-404_PREIMPLEMENTATION_BLUEPRINT_2026-04-28.md
-> only match is the file's own title line; no mention of 13128/1556/12969.

sqlite3 read-only query against D:/QM/strategy_farm/state/farm_state.sqlite,
table ea_metrics, filtered to (QM5_13128,NDX.DWX), (QM5_1556,XAUUSD.DWX),
(QM5_12969,USDJPY.DWX) -- see CSV for full rows.
```

No source, calendar seed, work item, pipeline verdict, terminal, T_Live, or
AutoTrading state was changed. This is a read-only verification pass.

## Deterministic resume conditions

Re-route once `G:\` (GoogleDriveFS) is mounted and reachable in the agent's
session, so the actual blueprint document can be located and read, or once
OWNER/Codex points at the document's canonical path directly (its exact
filename/location was never given in the task payload — only "blueprint
\u00a72/\u00a71").

## Changed files

- `docs/ops/evidence/2026-08-23_sp_f1_q10_survivor_matrix_verification.csv` (new, 3 rows)
- `docs/ops/evidence/2026-08-23_sp_f1_q10_survivor_matrix_verification.md` (this file, new)

This artifact remains in REVIEW for Codex/OWNER close-out.
