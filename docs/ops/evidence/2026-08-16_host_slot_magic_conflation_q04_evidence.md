# Host-slot magic conflation — silent evidence loss at Q04 (2026-08-16)

Investigated by Claude after the third `stream_and_selfreport_missing` Q04
verdict in one day (QM5_11424 AUDUSD all folds, QM5_11424 GBPUSD all folds,
QM5_11162 XAUUSD F2). The first hypothesis (zero-trade folds mistaken for
missing evidence) is **disproved**: the guard only fires when the tester
report itself shows trades (`q04_walkforward.py:1006`).

## What actually happens

The failing folds ran clean — `result=PASS`, `real_ticks_marker=true`,
13/17/19 trades across F1/F2/F3
(`D:/QM/reports/work_items/536bb9c7-4c86-4676-a762-83573513012a/QM5_11424/
20260816_06{1800,2143,2447}/summary.json`) — yet neither Common-Files output
was written:

- missing: `…/Common/Files/QM/q08_trades/11424_GBPUSD_DWX.jsonl`
- missing: `…/Common/Files/QM/q04_sim/11424_GBPUSD_DWX.json`
- present for the same EA on EURUSD: both files (06:12), which is why
  QM5_11424 EURUSD got a real economic Q04 verdict and the other symbols did
  not.

The EA logger from the fold's agent
(`D:/QM/mt5/T2/Tester/Agent-127.0.0.1-3005/MQL5/Files/QM/QM5_11424_ea-11424.log`)
shows the divergence directly:

| event | magic | note |
|---|---|---|
| `INIT` | `114240001` | framework identity, registry slot 1 for GBPUSD.DWX |
| `KILL_SWITCH_INIT` | `114240001` | kill switch registers the same |
| `ENTRY_ACCEPTED` | `114240000`, `"symbol_slot": 0` | **the orders use slot 0** |

Registry (`framework/registry/magic_numbers.csv`): `11424,…,1,GBPUSD.DWX,
114240001,active`. The fold setfile carries `qm_magic_slot_offset=1`.

## Mechanism

`QM_EntryRequest`'s constructor sets `symbol_slot = 0` and documents it as
"the host slot, the correct default for every single-symbol EA"
(`QM_Entry.mqh:22-39`). But `QM_Entry` turns that *relative* host slot into an
*absolute* registry slot:

```
magic = QM_MagicChecked(g_qm_entry_ea_id, req.symbol_slot, _Symbol);   // QM_Entry.mqh:251
```

`QM_MagicChecked` validates that `(ea_id, slot)` is registered but never
validates that the registry's symbol for that slot **is `_Symbol`**. On a
symbol whose registry slot is non-zero the call therefore returns another
symbol's magic — silently, with no reject and no warning.

Everything downstream keys on ownership
(`QM_FrameworkOwnsMagicSymbol`, `QM_Common.mqh:595`):

1. `QM_FrameworkQ08EmitFromHistory()` finds no owned deals → empty stream;
2. the Q04 sim accounting stays at `g_qm_sim_closed_deals = 0` → no
   `Q04_SIM_COMMISSION` event, no `q04_sim` json (both conditions are in the
   same `if`, `QM_Common.mqh:1775`);
3. Q04 grades neither from the stream nor from the self-report →
   `stream_and_selfreport_missing` → **false INFRA_FAIL**;
4. `QM_KillSwitchOwnsMagic()` is false for the EA's own positions — the
   daily-loss / DD halt cannot act on them (live-safety class, see below);
5. two symbols of one EA would trade under the same base magic, which is
   exactly the collision the registry exists to prevent.

EAs that assign the slot explicitly are provably unaffected: QM5_11104,
QM5_1638, QM5_10118 all carry `req.symbol_slot = qm_magic_slot_offset;` and
emitted streams today on registry slots 2-3.

## Live exposure: none

All 24 active `C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets\*.set` belong to EAs
that wire the slot; 13 of them run with `qm_magic_slot_offset != 0`
(13301/10=wired, 1567/7, 1556/4, 10911/3, 10440/3, 10513/3, 12567/3+2,
12989/3, 10403/2, 11165/2, 10706/1, 10919/1, 10939/1). **No live kill switch
is blind.** The 75 offset-carrying setfiles found under
`Presets\_archiv_alte_setfiles\` are archived, not deployed.

## Failure is fail-closed, not false-PASS

On affected pairs the graded verdicts are 99×Q02 and 17×Q03 — both grade from
the tester report and are unaffected. The only higher-phase verdicts
(QM5_10571 XAUUSD, Q04 PASS_SOFT / Q05 / Q06, July) demonstrably traded under
the **correct** magic `105710003` (stream file content), although that EA also
never assigns `symbol_slot` — so a second code path supplies the right magic
there (V3 runtime execution contract is the prime suspect,
`QM_Entry.mqh:257`). Determining which EAs take which path is the open
question and bounds the true blast radius.

## Blast radius (upper bound, to be narrowed)

`artifacts/unwired_magic_slot_scan_20260816.json`: 708 of 3568 EA sources
never assign `symbol_slot`; intersected with non-zero registry slots that is
797 (EA, symbol) pairs. Current queue exposure is small: **47 open rows sit at
Q02** (unaffected until Q04) and exactly **one** open row is already at Q04
(`4619255d` QM5_2002 XAUUSD). That row is deliberately left running as a
natural experiment: if it fails with the same reason the detector is
confirmed; if it passes, the detector over-counts and the V3-path hypothesis
is strengthened.

## Handoff

Framework fix shape (task `18954866`, Codex):

1. host-slot semantics: when `explicit_magic == 0` and `req.symbol_slot == 0`,
   resolve the **framework host magic** (`g_qm_fw_magic`, which already
   encodes `qm_magic_slot_offset`) instead of `QM_MagicChecked(ea, 0, …)`;
2. defense in depth: `QM_MagicChecked(ea, slot, expected_symbol)` must reject
   when the registry's symbol for `(ea, slot)` differs from `expected_symbol`
   — a silent foreign magic must become a loud `magic_resolution_failed`;
3. determine why V3-contract EAs are immune and record the two paths;
4. re-scan with the corrected detector, then stage rebuild + requalification
   (QM5_11424 first: it swept Q02 5/5 and is blocked on 3 of 4 symbols).

No source, setfile or registry row was mutated by this investigation.
