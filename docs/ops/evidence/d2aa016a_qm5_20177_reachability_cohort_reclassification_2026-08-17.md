# QM5_20177 reachable fixture, cohort reconciliation, and defective-binary row repair

Date: 2026-08-17 (Europe/Berlin)

- Router task: `d2aa016a-c472-492d-b165-0cc09da3be78`
- Task type / priority: `triage_failure` / `78`
- Branch: `agents/board-advisor`
- Implementation commit: `f9e2d1fc091312ca3161cca9f81cfe0ad9597941`
- Defective EX5 SHA-256:
  `1a2f22d4edc56afdbabd403bda0bc330c0667f7c3e859b9dc3f7c5689d5e1f09`

## Verdict

**PASS FOR REVIEW: all three requested corrections are complete.** The positive
fixture now proves reachability through an EA-equivalent fractal search using
valid OHLC bars; the cohort is reproducibly enumerated EA by EA; and every
completed Q02 row bound to the defective EX5 is now classified
`DRAFT_DEFECT`. This is an implementation/evidence correction, not a pipeline
verdict and not authorization to advance the Gemini build task.

## 1. Reachable positive fixture

`tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py` no
longer injects `A`, `B`, `C`, `ab_bars`, or `c_shift`. It now:

1. validates every synthetic bar with
   `low <= open/close <= high`;
2. derives strict five-bar upper/lower Williams fractals;
3. scans from shift 4 in the same newest-to-oldest order as MQ5 `FindABC`;
4. skips ambiguous and same-polarity pivots; and
5. derives A/B/C and all bar distances from the selected window before running
   ratio, time-symmetry, touch, confirmation, cooldown, and T1-room gates.

The valid bullish window selects `C=104` at shift 5 (lower), `B=110` at shift
8 (upper), and `A=100` at shift 11 (lower). Therefore `AB bars=3`, `CD
bars=3`, `BC/AB=0.6`, `D_proj=114`, and `T1=110.18`. Its valid touch bar is
`O/H/L/C=109.70/109.80/109.50/109.60`; the valid confirmation bar closes at
`109.90 > 109.80`; and `Ask=110.00 < T1`. The complete simulated entry path
accepts it.

The symmetric valid bearish window selects `A=120`, `B=110`, `C=116` at the
same shifts and is also accepted. A separate valid bullish window with a
5x-ATR AB leg reaches touch and confirmation but has `Ask=169.60 > T1=150.90`
and is rejected. This establishes that the search can reach both acceptance
and rejection; it does not infer real-data signal frequency.

## 2. Cohort reconciliation by enumeration

The committed generator
`tools/strategy_farm/audit_pattern_target_management.py` selects EA
directories by the slug only (never by the numeric `QM5_<id>` prefix), masks
comments and literals, extracts `Strategy_ManageOpenPosition`, hashes every
examined source, and emits one disposition row per selected directory.

Exact fresh result:

| Disposition | Count |
|---|---:|
| `EMPTY_MANAGEMENT_HOOK` | 54 |
| `MANAGEMENT_ANCHORED_TO_FILL` | 19 |
| `OTHER_MANAGEMENT_NO_EXACT_SIGNATURE` | 20 |
| `UNANCHORED_SIGNAL_PROJECTION_TARGETS` | 1 |
| `NO_MQ5_SOURCE` | 1 |
| **Total directories enumerated** | **95** |
| **Source-bearing directories / files examined** | **94 / 94** |

The sole exact signature is
`QM5_20177_carney-ab-cd-pattern-h4-r1-recovery`. The previously omitted
source-bearing EAs are present explicitly:

- `QM5_11891_unger-daily-factor-indecision-pattern` ->
  `OTHER_MANAGEMENT_NO_EXACT_SIGNATURE` (pending-order housekeeping);
- `QM5_11892_samuels-123-reversal-pattern` ->
  `OTHER_MANAGEMENT_NO_EXACT_SIGNATURE` (bar-count time stop).

`QM5_11213_ft-cofibit` is the one selected directory with no MQ5 source and is
reported as `NO_MQ5_SOURCE`, not silently treated as immune. Likewise, the 20
`OTHER_MANAGEMENT_NO_EXACT_SIGNATURE` rows are not relabelled as pipeline or
strategy PASS. The complete list of all 95 EAs, matched terms, source paths,
source hashes, lexical signals, and dispositions is in
`d2aa016a_qm5_20177_pattern_target_management_audit_2026-08-17.json`.

Reproduction:

```powershell
python tools/strategy_farm/audit_pattern_target_management.py `
  --output C:\QM\repo\docs\ops\evidence\d2aa016a_qm5_20177_pattern_target_management_audit_2026-08-17.json `
  --check
```

Result: `PASS`, JSON SHA-256
`b55e5b7204c0d9dde96de0d2776d54f7985215ade7ccbc6bae83078a4e13af00`.

## 3. Hash-keyed Q02 reclassification

The committed controller
`tools/strategy_farm/reclassify_defective_binary_work_items.py` produced a
read-only exact-set plan, then applied only that plan under the global Factory
mutation lock. Apply required the exact plan hash, made an online SQLite
backup, rechecked every full row preimage, used compare-and-swap updates, and
appended transition-ledger and event records.

| Work item | Symbol | Before | After |
|---|---|---|---|
| `cd946f00-aa75-4d11-b119-1cd2a2e51d90` | EURUSD.DWX | `FAIL` | `DRAFT_DEFECT` |
| `ba38e217-fc92-4265-8678-f6c910f898e8` | GBPUSD.DWX | `FAIL` | `DRAFT_DEFECT` |
| `cd2f56fd-ae3f-4ab0-a875-fbc77c09dc66` | NDX.DWX | `ZERO_TRADES` | `DRAFT_DEFECT` |
| `c7f7a083-837c-470e-9501-fec5eb566f28` | USDJPY.DWX | `DRAFT_DEFECT` | `DRAFT_DEFECT` (audit payload normalized) |
| `a0c57304-3d83-4e02-a414-3561736f0eb5` | WS30.DWX | `FAIL` | `DRAFT_DEFECT` |
| `90c7c269-8038-4c9c-8bbf-e8747bf4ea32` | XAUUSD.DWX | `FAIL` | `DRAFT_DEFECT` |

The post-apply read-only verification found exactly six rows keyed to the
defective EX5, all `done`, unclaimed, `DRAFT_DEFECT`, and carrying
`verdict_taxonomy=implementation` plus one durable reclassification-history
entry. It also found six append-only transition-ledger rows and six matching
events.

- Plan:
  `d2aa016a_qm5_20177_defective_binary_reclassification_plan_2026-08-17.json`
- Plan SHA-256:
  `89f5daad91eb47ad627aa9e09ac7ba92d4deb5e905dbfbf9eaaac51c7892b0ae`
- Receipt:
  `d2aa016a_qm5_20177_defective_binary_reclassification_receipt_2026-08-17.json`
- Receipt SHA-256:
  `b399f684d2799822270af40daf87bde4f1fd7c618b7e4c232c4ce851381c3753`
- Pre-mutation backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_20177_defective_binary_20260817032228Z.sqlite`
- Backup SHA-256:
  `418f01bdf359d7e2a48181f6ee2f510fb43e424766d45ac1ba9f9e5702c7c9d1`

All six raw `summary.json` files remain byte-identical to the hashes sealed in
the plan. No work item was enqueued or rerun. The repaired-binary USDJPY Q02
canary `af79d508-0959-4a93-bd2d-f3178a68f633` remains `pending` with no
verdict and was not touched.

## Focused verification

```text
python -m pytest \
  tools/strategy_farm/tests/test_reclassify_defective_binary_work_items.py \
  tools/strategy_farm/tests/test_audit_pattern_target_management.py \
  tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py -q
.......                                                                  [100%]
7 passed

python tools/strategy_farm/validate_build_guardrails.py \
  framework/EAs/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery
PASS; 7 files checked; no findings; max news stale hours=336
```

Artifact hashes:

| Artifact | SHA-256 |
|---|---|
| Reachability test | `8d869b746e5c305c504966e0e4f571d77b80e93324262ba3bf00bae4a5d6acf8` |
| Cohort generator | `a6bd95c170afd30673f82fe6689f1ce9d4f5d8fad371352cd59efb4833c24296` |
| Reclassification controller | `13e44fe84183e3f06ad61c2ebd252e429a2ef38365aaaafee16db3e3baa2c01d` |

## Scope and safety

- No EA source, EX5, setfile, registry, Strategy Card, or gate was changed.
- No pipeline verdict is inferred from a test or source audit.
- No active terminal/backtest was interrupted.
- `T_Live`, AutoTrading, and `terminal64.exe` were untouched.
- News staleness remains fail-closed at 336 hours; all backtest setfiles remain
  fixed-risk (`RISK_FIXED > 0`, `RISK_PERCENT = 0`).
- This task is handed to reviewer state only; it does not self-approve the
  Gemini source task or move any work to PIPELINE.
