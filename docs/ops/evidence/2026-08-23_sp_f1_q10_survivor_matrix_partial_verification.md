# SP-F1 Q10 Survivor Matrix vs State-DB — Partial Verification + Blocker

Date: 2026-08-23

Router task: `cb771748-c85d-4819-87c7-98535ab0c047` (`SP-F1`, priority 45,
zone GRUEN)

## Verdict

PARTIAL — the three live-status claims named in the routed payload
(`13128 "laeuft live"`, `1556 "bewaehrter Sleeve"`, `12969 "Kern-Saeule"`)
are **independently confirmed against Registry/T_Live/state-DB evidence**
below. The full 13-EA CSV the acceptance criteria asks for (all 13 rows,
DB-measured vs. document-claimed Trades/PF/maxDD, match/mismatch flag)
**could not be produced**: this headless session has no `G:` mount (the
Vault, where the "Blueprint" this task cites almost certainly lives, is
confirmed inaccessible — see Blocker below), and a targeted search of the
repo (`docs/`, `artifacts/`, `decisions/`) and the Notion workspace found no
document with a "Section 2" 13-EA matrix. Only the 3 EA IDs named directly in
the task payload are known; the other 10 are not.

## Blocker — confirmed, not assumed

```text
PS> Test-Path 'G:\My Drive'
Test-Path : Access is denied
False
```

This is the identical constraint already on record for `SP-D8`
("SP-D8 Vault-Redaktion ist Claude-Arbeit mit G:-Zugriff (headless hat
keinen Mount) - Codex hat korrekt gehalten"). Repo-side search performed
before concluding this: `13128` found in 20 `docs/`-tree files (none is a
"Blueprint" with a Section 2 EA matrix), targeted phrase/ID searches in
`artifacts/` and `decisions/` for the exact three EA IDs together, and a
Notion workspace search for "Blueprint QM5_13128 QM5_1556 QM5_12969 survivor
matrix book" (10 results, all unrelated April/May-2026 infra pages). No
repo-committed or Notion candidate found.

**Resume condition:** either (a) a session with `G:` access (interactive
Claude, or a router dispatch carrying the document content/the other 10 EA
IDs directly in the task payload) supplies the Blueprint's Section 1/2 text,
or (b) the Blueprint gets committed into the repo so headless sessions can
read it. Re-route SP-F1 (or a follow-up task) once either is true.

## Confirmed: the 3 named live-status claims

### QM5_13128 (`pre-fomc-drift-ndx`) — "laeuft live"

| Check | Result |
|---|---|
| Magic registry (`framework/registry/magic_numbers.csv:14936`) | `13128,pre-fomc-drift-ndx,0,NDX.DWX,131280000,2026-07-10,claude,active` |
| T_Live `.ex5` present | `C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts\Live EAs\QM5_13128_pre-fomc-drift-ndx.ex5` |
| Current (non-archived) preset | `Presets\14_NDX_H1_QM5_13128_pre-fomc-drift-ndx.set` (chart slot 14) |
| Preset config | `environment: live`, `RISK_FIXED=0`, `RISK_PERCENT=1.0000` (correct live risk mode per Hard Rule) |
| State-DB Q10 (closing verdict) | `PASS`, symbol `NDX.DWX`, trades=57, PF=2.29, maxDD=1.25% |
| Note | `Q09_PORTFOLIO` row for this EA/symbol reads `NEED_MORE_DATA`, not `PASS_PORTFOLIO`, yet `Q10` still reads `PASS`. Recorded as observed, not resolved — flagging for whoever owns Q09_PORTFOLIO-vs-Q10 sequencing semantics rather than assuming it is an error. |

**Verdict on this claim: CONFIRMED** ("laeuft live" is fully supported —
active registry entry, deployed binary, current live-environment preset with
correct risk mode, closing Q10 PASS on the same symbol).

### QM5_1556 (`aa-zak-mom12`) — "bewaehrter Sleeve" (proven sleeve)

| Check | Result |
|---|---|
| Magic registry (`:13756-13764`) | 9 symbol slots registered, all `active` |
| T_Live `.ex5` present | `C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts\Live EAs\QM5_1556_aa-zak-mom12.ex5` |
| Current (non-archived) preset | `Presets\22_XAUUSD_D1_QM5_1556_aa-zak-mom12.set` (chart slot 22, XAUUSD.DWX only) |
| Preset config | `environment: live`, `RISK_FIXED=0`, `RISK_PERCENT=0.6017` |
| State-DB Q10 (closing verdict, XAUUSD.DWX) | `PASS`, trades=53, PF=1.93, maxDD=2.68% |
| Cross-symbol context | Q02 rows show this EA `FAIL`ed on EURUSD/GBPUSD/GDAXI/NDX and `PASS_LOWFREQ`/`PASS`ed on SP500/USDJPY/WS30/XAUUSD/XTIUSD — i.e. it is a genuinely mixed multi-symbol EA where only a subset of symbols survived, and the one live-deployed symbol (XAUUSD.DWX) is exactly the one that reached Q10 PASS. |

**Verdict on this claim: CONFIRMED as stated, with the qualifier the claim
itself implies.** "Sleeve" (not "EA") is the correct unit here — the label
"bewaehrter Sleeve" is accurate specifically for the XAUUSD.DWX sleeve, not
for QM5_1556 as a whole (most of its other symbol attempts failed earlier
gates). The live deployment correctly matches only the surviving sleeve.

### QM5_12969 (`usdjpy-gotobi-nakane-fix`) — "Kern-Saeule" (core pillar)

| Check | Result |
|---|---|
| Magic registry (`:14383`) | `12969,usdjpy-gotobi-nakane-fix,0,USDJPY.DWX,129690000,2026-07-03,Codex,active` |
| T_Live `.ex5` present | `C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts\Live EAs\QM5_12969_usdjpy-gotobi-nakane-fix.ex5` |
| Current (non-archived) preset | `Presets\17_USDJPY_M30_QM5_12969_usdjpy-gotobi-nakane-fix.set` (chart slot 17) |
| Preset config | `environment: live`, `RISK_FIXED=0`, `RISK_PERCENT=0.5100` |
| State-DB Q10 (closing verdict) | `PASS`, trades=331, PF=1.54, maxDD=2.02% |

**Verdict on this claim: CONFIRMED as a live, passing sleeve.** "Kern-Saeule"
(core pillar) is a qualitative characterization this task cannot itself
prove or disprove from pipeline evidence alone (that would need a portfolio
weighting/allocation document, which is exactly part of the inaccessible
Blueprint) — but the underlying factual basis (active, deployed, Q10 PASS
with a substantial 331-trade sample and PF 1.54) is real and not an
overstatement.

## What this partial CSV covers

```text
ea_id,symbol,phase,verdict,trades,profit_factor,drawdown_pct,live_registry_active,live_ex5_present,live_preset_current,live_risk_mode_correct
QM5_13128,NDX.DWX,Q10,PASS,57,2.29,1.25,true,true,true,true
QM5_1556,XAUUSD.DWX,Q10,PASS,53,1.93,2.68,true,true,true,true
QM5_12969,USDJPY.DWX,Q10,PASS,331,1.54,2.02,true,true,true,true
```

The remaining 10 of 13 rows require the Blueprint's Section 2 matrix (for
the EA IDs) and Section 1 (for whatever document-claimed Trades/PF/maxDD
values need a match/mismatch flag against these same DB columns) — see
Blocker above.

## Checks performed

- `farm_state.sqlite` `ea_metrics` table, read-only, queried by `QM5_`-prefixed
  `ea_id` (the correct stored format — bare-numeric rows exist for a
  different, unrelated ID namespace and would silently return wrong/empty
  results if used here).
- `framework/registry/magic_numbers.csv` grep for all three EA IDs.
- `C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts\Live EAs\` and `...\Presets\`
  directory listings for all three EA IDs, distinguishing current presets
  from the two archive folders (`_archive_dxz24_superseded`,
  `_archiv_alte_setfiles`).
- Preset file content (`RISK_FIXED`/`RISK_PERCENT`/`environment` header) for
  all three current presets.
- `G:\My Drive` accessibility (confirmed denied), repo-wide targeted search
  for a Blueprint document, Notion workspace search.

No T_Live state, AutoTrading toggle, work item, or pipeline verdict was
changed. This is verification-only, per the task's own hard_constraint
("reine Verifikation, kein Buch-Bildung").
