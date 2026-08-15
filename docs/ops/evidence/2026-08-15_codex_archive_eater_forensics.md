# 2026-08-15 — Archive-eater forensics (Codex B-side)

**Status:** REVIEW — read-only forensics complete; no gate, containment,
terminal, scheduled-task, or archive state was changed.

**Router task:** `bc487116-c142-472c-9fa9-9df1e8e69ad2`

**Evidence cutoff:** 2026-08-15 11:54Z (13:54 CEST). The repair ledger at
cutoff is SHA-256
`F64A216013704192F4E78359B9E834BBFF89FA2C66B1089558DC61638C135C7A`.
Source: `D:\QM\strategy_farm\state\custom_history_repairs.jsonl`.

## Verdict

**High confidence:** the continuing archive losses are residual cross-terminal
hardlink collisions on **non-claimed (bystander) custom symbols**. DL-085 is
working as designed as a repair/source-safety layer, but it does not remove the
collision surface: copy-on-claim privatizes only the claimed host plus declared
conversion/basket symbols. Every other symbol can remain a family hardlink in
multiple active `T1`–`T10` `Bases\Custom` trees. Sources:
`C:\QM\repo\tools\strategy_farm\terminal_worker.py:1258-1297` and
`C:\QM\repo\tools\strategy_farm\custom_history_copy_on_claim.py:153-200`.

The 15 August AUDCAD incident closes the causal chain. T4 and T6 were testing
XNGUSD and CADCHF, respectively, yet both MT5 journals reported an AUDCAD file
opening/reading error 32 within 503 ms. At that same second the D: USN journal
recorded hardlink changes against T4's AUDCAD 2017/2018 paths and T6's AUDCAD
2019 path. The next worker gate restored exactly those three paths from the
verified master 83–84 seconds later. Sources:
`D:\QM\reports\work_items\1c14beae-358f-402c-84ac-a6ed6f51d90f\QM5_1537\20260815_100146\raw\run_01\tester.ini:2-4`,
`D:\QM\reports\work_items\23954007-b614-45d4-b563-ba480d085ccc\QM5_1537\20260815_100258\raw\run_02\tester.ini:2-4`,
`D:\QM\mt5\T4\logs\20260815.log:33-34`,
`D:\QM\mt5\T6\logs\20260815.log:115`,
`D:\$Extend\$UsnJrnl:$J` USNs `467170640`, `467170720`, and `467193280`, and
`D:\QM\strategy_farm\state\custom_history_repairs.jsonl:115-117`.

USN is process-neutral: it records the namespace mutation, file identity,
parent identity, reason, and time, not the PID. Therefore the statement that
MT5 performed the unlink is an evidence-backed attribution, not direct PID
auditing. The exact-time MT5 errors, bystander status, parent/file identity
match, subsequent missing-path repair, and exclusion of cleanup scope make an
unrelated deleter materially implausible. Sources:
`D:\$Extend\$UsnJrnl:$J`,
`D:\QM\mt5\T4\logs\20260815.log:33-34`,
`D:\QM\mt5\T6\logs\20260815.log:115`, and
`D:\QM\reports\state\tester_cache_purge.log:20553-20596`.

## Concrete 15 August causal chain

### 1. Copy-on-claim left AUDCAD as a bystander family

T4's claim receipt at 09:58:23Z selected 108 XNGUSD files; T6's receipt at
10:00:11Z selected 108 CADCHF files. Both used the DL-085 master as read source
and passed privatization. Neither claim selected AUDCAD. Sources:
`D:\QM\strategy_farm\artifacts\ops\custom_history_copy_on_claim\1c14beae-358f-402c-84ac-a6ed6f51d90f_T4.json:2-3,1088-1098` and
`D:\QM\strategy_farm\artifacts\ops\custom_history_copy_on_claim\23954007-b614-45d4-b563-ba480d085ccc_T6.json:2-3,1088-1098`.

The selection behavior is explicit in code: archive rows are selected from the
claim's symbol set, then only those rows are copied/replaced. The copy reads
from `Custom_master`, verifies size and SHA-256, and atomically replaces the
selected target. Sources:
`C:\QM\repo\tools\strategy_farm\custom_history_copy_on_claim.py:100-108,153-185,192-260` and
`C:\QM\repo\tools\strategy_farm\terminal_worker.py:1264-1297`.

### 2. Concurrent MT5s touched the unclaimed AUDCAD family

T4's immutable tester config says `Symbol=XNGUSD.DWX`; T6's says
`Symbol=CADCHF.DWX`. Nevertheless, T4 logged AUDCAD error 32 at
12:06:38.351 and 12:06:38.353 local, and T6 logged the same at
12:06:38.854. This proves that an MT5 run can touch a bystander custom-symbol
archive outside its claimed host. Sources:
`D:\QM\reports\work_items\1c14beae-358f-402c-84ac-a6ed6f51d90f\QM5_1537\20260815_100146\raw\run_01\tester.ini:2-4`,
`D:\QM\reports\work_items\23954007-b614-45d4-b563-ba480d085ccc\QM5_1537\20260815_100258\raw\run_02\tester.ini:2-4`,
`D:\QM\mt5\T4\logs\20260815.log:33-34`, and
`D:\QM\mt5\T6\logs\20260815.log:115`.

### 3. NTFS recorded the affected terminal links changing at that second

The D: journal was active with ID `0x01dd2bceeb41047e`; its observed retained
range was `0x19000000` through at least `0x216bc4d0`, covering the incident.
Source: `D:\$Extend\$UsnJrnl:$J` (`fsutil usn queryjournal D:` at the evidence
cutoff).

The relevant CSV records are:

| Local time | USN | Name | Reason | File ID | Parent ID | Parent mapping |
|---|---:|---|---|---|---|---|
| 12:06:38 | 467170640 | `2017.hcc` | `HARD_LINK_CHANGE | CLOSE` | `00000000000000000011000000019b4f` | `000000000000000000020000001016f5` | T4 AUDCAD |
| 12:06:38 | 467170720 | `2018.hcc` | `HARD_LINK_CHANGE | CLOSE` | `00000000000000000011000000019b50` | `000000000000000000020000001016f5` | T4 AUDCAD |
| 12:06:38 | 467193280 | `2019.hcc` | `HARD_LINK_CHANGE | CLOSE` | `00000000000000000001000000019b51` | `000000000000000000080000001038f6` | T6 AUDCAD |

Source: `D:\$Extend\$UsnJrnl:$J`, read with
`fsutil usn readJournal D: csv`. `fsutil file queryfileid` maps parent
`0x000000000000000000020000001016f5` to
`D:\QM\mt5\T4\Bases\Custom\history\AUDCAD.DWX` and parent
`0x000000000000000000080000001038f6` to
`D:\QM\mt5\T6\Bases\Custom\history\AUDCAD.DWX`.

Those old file IDs still identify the surviving family members. For example,
T1's AUDCAD 2017 file ID is
`0x00000000000000000011000000019b4f`, and `fsutil hardlink list`
shows T1/T2/T3/T5/T6/T7/T8/T10 plus the rollback link, but not T4. The 2018
family likewise excludes T4; the 2019 family excludes T6. The repaired T4
2017/2018 files now have private IDs
`0x0000000000000000000d0000000072c3` and
`0x0000000000000000000f000000007303`; repaired T6 2019 has
`0x0000000000000000000f00000000733e`. Sources:
`D:\QM\mt5\T1\Bases\Custom\history\AUDCAD.DWX\2017.hcc`,
`D:\QM\mt5\T1\Bases\Custom\history\AUDCAD.DWX\2018.hcc`,
`D:\QM\mt5\T1\Bases\Custom\history\AUDCAD.DWX\2019.hcc`,
`D:\QM\mt5\T4\Bases\Custom\history\AUDCAD.DWX\2017.hcc`,
`D:\QM\mt5\T4\Bases\Custom\history\AUDCAD.DWX\2018.hcc`, and
`D:\QM\mt5\T6\Bases\Custom\history\AUDCAD.DWX\2019.hcc`.

`HARD_LINK_CHANGE`, rather than final `FILE_DELETE`, is the expected NTFS
record when one pathname is unlinked but other names still reference the same
file record. The surviving family IDs and the later private repair IDs confirm
that this was loss of the terminal pathname, not loss of the shared content.
Sources: the six live paths above and `D:\$Extend\$UsnJrnl:$J` USNs
`467170640`, `467170720`, and `467193280`.

### 4. DL-085 repaired, but did not prevent, the loss

At 10:08:01Z the T10 worker gate restored T4 AUDCAD 2017 and 2018; at
10:08:02Z it restored T6 AUDCAD 2019. All three receipts are
`REPAIRED_VERIFIED` with manifest SHA-256 and size. The USN journal separately
records `.master-repair.*.tmp` creation and atomic rename at those times.
Sources: `D:\QM\strategy_farm\state\custom_history_repairs.jsonl:115-117`
and `D:\$Extend\$UsnJrnl:$J` USNs `471151712` through `471196368`.

This is exactly the boundary of DL-085: repair from a verified standalone
master and master-sourced claim privatization are present, but bystander family
links remain in active terminals. Sources:
`C:\QM\repo\decisions\2026-08-14_self_healing_archive_gate.md` and
`C:\QM\repo\tools\strategy_farm\custom_history_copy_on_claim.py:153-185`.

## Why the alarm said 114, and what the current rate means

The ledger has 117 records at cutoff:

- 49 are the one-time `claude_dl085_mass_restore_20260814` at
  09:10:28–09:10:30Z on 14 August. They were recovery bookkeeping, not 49
  post-DL-085 loss events. Source:
  `D:\QM\strategy_farm\state\custom_history_repairs.jsonl:1-49`.
- 52 are one gate's batched fleet repair at 16:42:07–16:42:11Z on 14 August.
  The batch represents already-missing terminal paths discovered together; it
  is not a 52-per-gate steady arrival rate. Source:
  `D:\QM\strategy_farm\state\custom_history_repairs.jsonl:58-109`.
- 13 were other worker-gate repairs before the new AUDCAD event (eight before
  the batch and five later on 14 August). Sources:
  `D:\QM\strategy_farm\state\custom_history_repairs.jsonl:50-57,110-114`.
- Three are the USN-proven AUDCAD losses on 15 August. Source:
  `D:\QM\strategy_farm\state\custom_history_repairs.jsonl:115-117`.

Thus the earlier 114/24h alarm was the first 114 ledger rows: 49 administrative
mass-restore receipts plus 65 worker repairs. It overstated ongoing loss by
mixing recovery bookkeeping with organic events. The current code filters to
`worker_gate:*`; a health probe during this investigation returned 60, composed
of the 52-file batch, five later 14 August repairs, and three new AUDCAD repairs.
Sources: `C:\QM\repo\tools\strategy_farm\custom_history_master.py:277-312`,
`C:\QM\repo\tools\strategy_farm\health.py:894-927`, and
`D:\QM\strategy_farm\state\custom_history_repairs.jsonl:58-117`.

The alert is therefore partly a window/batch-accounting artifact, but the three
new AUDCAD rows prove the underlying collision is still active after DL-085.
Sources: `D:\QM\strategy_farm\state\custom_history_repairs.jsonl:115-117`,
`D:\QM\mt5\T4\logs\20260815.log:33-34`, and
`D:\QM\mt5\T6\logs\20260815.log:115`.

## Cleanup-task exclusion

`tester_cache_purge.ps1` deletes only `Tn\Tester\bases` and
`Tn\Tester\Agent-*`; it has no `Bases\Custom` delete target. More decisively,
its runs at 10:00, 10:04, 10:05, and 10:06Z classified both T4 and T6 as
protected and explicitly skipped them. Sources:
`C:\QM\repo\tools\strategy_farm\tester_cache_purge.ps1:6-9,180-186` and
`D:\QM\reports\state\tester_cache_purge.log:20553-20596`.

The other installed QM cleanup scripts are scoped to stale inbox Markdown or
old report `.log` files, not terminal archives. Sources:
`C:\QM\repo\tools\strategy_farm\inbox_cleanup.py:1-7,30-53` and
`C:\QM\repo\tools\strategy_farm\reports_log_purge.ps1:3-17,30-54`.

Copy-on-claim itself is also excluded for these AUDCAD paths: its two receipts
selected only XNGUSD and CADCHF, and its write sequence is temp copy, verify,
then atomic `os.replace` for selected rows. Sources:
`D:\QM\strategy_farm\artifacts\ops\custom_history_copy_on_claim\1c14beae-358f-402c-84ac-a6ed6f51d90f_T4.json:1088-1098`,
`D:\QM\strategy_farm\artifacts\ops\custom_history_copy_on_claim\23954007-b614-45d4-b563-ba480d085ccc_T6.json:1088-1098`, and
`C:\QM\repo\tools\strategy_farm\custom_history_copy_on_claim.py:192-260`.

## Minimal structural fix proposed (not applied)

Adopt a **sparse active Custom-history contract per claim**:

1. Before terminal launch, retain in the target terminal only the host plus
   declared conversion/basket symbol archives; remove non-required terminal
   pathname links from that terminal's active `Bases\Custom\history` view.
2. Change the dispatch audit so master integrity remains global, while target
   terminal completeness is required only for the claim symbol set. Missing
   bystanders must be recorded as `PRUNED_BY_DESIGN`, not repaired as
   `MANIFEST_ARCHIVE_FILE_MISSING`.
3. Restore each newly required symbol from `Custom_master`, then run the
   existing copy-on-claim verification so every archive visible to the booting
   MT5 is terminal-private.

This is the smallest design that removes the proven collision surface without
serializing the fleet or multiplying the full archive tree tenfold. It extends,
rather than weakens, the DL-085 master/verification model. Relevant current
boundaries: `C:\QM\repo\tools\strategy_farm\custom_history_gate.py`,
`C:\QM\repo\tools\strategy_farm\custom_history_master.py`,
`C:\QM\repo\tools\strategy_farm\custom_history_copy_on_claim.py`, and
`C:\QM\repo\tools\strategy_farm\terminal_worker.py`.

A temporary start stagger can reduce collision probability but cannot remove
shared bystander inodes; whole-run serialization would remove factory
parallelism. Re-applying deny-delete ACLs under the present single Windows
identity would conflict with worker `os.replace`, and full physical
privatization is the highest-disk option. Sources:
`C:\QM\repo\tools\strategy_farm\custom_history_copy_on_claim.py:231-251` and
`C:\QM\repo\docs\ops\evidence\2026-08-14_claude_archive_eater_forensics.md`.

## Acceptance test for the proposed fix

Under a governed non-live factory test, run at least two overlapping claims
whose hosts differ and include AUDCAD only as a bystander. Require all of:

- no error 32 for a non-claim symbol in `D:\QM\mt5\T*\logs\YYYYMMDD.log`;
- no `HARD_LINK_CHANGE`/unlink USN record for a non-claim terminal archive in
  `D:\$Extend\$UsnJrnl:$J`;
- no new `MANIFEST_ARCHIVE_FILE_MISSING` worker repair for a bystander in
  `D:\QM\strategy_farm\state\custom_history_repairs.jsonl`;
- claim-scoped copy receipts remain `PASS_PRIVATIZED` under
  `D:\QM\strategy_farm\artifacts\ops\custom_history_copy_on_claim\`;
- master-missing or SHA-mismatch cases still fail closed through
  `C:\QM\repo\tools\strategy_farm\custom_history_master.py` and
  `C:\QM\repo\tools\strategy_farm\custom_history_gate.py`.

No such run was started for this read-only task, and no active T1–T10 backtest
was interrupted. Sources inspected only:
`D:\QM\strategy_farm\state\custom_history_repairs.jsonl`,
`D:\QM\strategy_farm\logs\terminal_worker_T1.log` through
`D:\QM\strategy_farm\logs\terminal_worker_T10.log`,
`D:\QM\mt5\T4\logs\20260815.log`,
`D:\QM\mt5\T6\logs\20260815.log`,
`D:\QM\reports\state\tester_cache_purge.log`,
`D:\QM\strategy_farm\artifacts\ops\custom_history_copy_on_claim\`, and
`D:\$Extend\$UsnJrnl:$J`.

## Focused verification receipt

Read-only assertions run after drafting returned PASS for: 117 ledger rows,
49 administrative restore rows, 68 `worker_gate:*` rows, the final three
T4/T4/T6 AUDCAD repairs, XNGUSD/CADCHF host configs, AUDCAD error 32 on both
terminals, and purge exclusion. Sources:
`D:\QM\strategy_farm\state\custom_history_repairs.jsonl`,
`D:\QM\reports\work_items\1c14beae-358f-402c-84ac-a6ed6f51d90f\QM5_1537\20260815_100146\raw\run_01\tester.ini`,
`D:\QM\reports\work_items\23954007-b614-45d4-b563-ba480d085ccc\QM5_1537\20260815_100258\raw\run_02\tester.ini`,
`D:\QM\mt5\T4\logs\20260815.log`,
`D:\QM\mt5\T6\logs\20260815.log`, and
`D:\QM\reports\state\tester_cache_purge.log`.

Independent `fsutil file queryfileid` assertions reproduced both parent IDs
and all three old family IDs in the table. A full journal replay filtered by
record number reproduced USNs `467170640`, `467170720`, `467193280`,
`471151712`, and `471196368` with the cited times, reasons, file IDs, and
parent IDs. Sources: the six `D:\QM\mt5\T*\Bases\Custom\history\AUDCAD.DWX`
paths cited above and `D:\$Extend\$UsnJrnl:$J`.

## Cross-review note

This B-side agrees with the A-side residual-bystander mechanism in
`C:\QM\repo\docs\ops\evidence\2026-08-15_claude_archive_eater_forensics.md`.
It adds the post-activation USN namespace evidence and corrects one detail:
the immutable configs show the incident hosts were XNGUSD on T4 and CADCHF on
T6, not AUDJPY and SP500. AUDCAD remains a bystander under either account, so
the correction strengthens rather than changes the causal verdict. Sources:
the two tester INIs cited above and `D:\QM\mt5\T4\logs\20260815.log:33-34`,
`D:\QM\mt5\T6\logs\20260815.log:115`.
