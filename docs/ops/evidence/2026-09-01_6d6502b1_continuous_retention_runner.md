# Continuous retention runner evidence — 6d6502b1

- Task: `6d6502b1-4aa8-4428-9074-bc8ae03caec2`
- Authority: `OWNER-DEC-BACKUP-RETENTION-20260830`
- Execution date: 2026-09-01 UTC
- Branch: `agents/board-advisor`
- Verdict: implementation is live and fail-closed; leave in REVIEW while the
  telemetry accumulates the requested 24-hour free-space trend.

## Delivered control

`tools/strategy_farm/continuous_retention_runner.py` is a single-pass runner
installed as `QM_StrategyFarm_ContinuousRetention_45min`. It does nothing when
D: has at least 150 GiB free. Below that watermark it obtains a singleton lock,
opens the live farm database read-only, requires `PRAGMA quick_check=ok`, and:

1. keeps the union of the newest 10 backups and all backups from the trailing
   14 days, NTFS-compresses the retained files, and sends only older files
   through an exact-root, receipt-first quarantine/delete batch;
2. NTFS-compresses at most 5,000 evidence files older than two hours per pass,
   excluding open work-item IDs and bound paths, reparse points, and files
   already compressed (so successive passes advance through the backlog);
3. rotates logs above 64 MiB only after an exclusive-open succeeds and retains
   current/last-48-hour logs; open worker logs are held rather than disturbed;
4. emits bounded status/byte telemetry and detailed per-run receipts.

The runner never writes farm DB rows, verdicts, ledgers, terminal state,
`T_Live`, or AutoTrading. Filesystem actions require `--apply`. No terminal or
backtest was stopped.

## Live schedule

- Account: `SYSTEM`; hidden; highest run level
- Action: `C:\Python311\python.exe "C:\QM\repo\tools\strategy_farm\continuous_retention_runner.py" --apply`
- Working directory: `C:\QM\repo`
- Interval: `PT45M`; multiple instances: `IgnoreNew`
- Execution limit: `PT40M`
- First scheduled run: `2026-09-01T18:34:34+02:00`
- First scheduled result: `0`; next observed run: `2026-09-01T19:19:19+02:00`

## Execution evidence

| Run UTC | Mode | DB check | Evidence result | Log result | Free-space delta |
|---|---|---|---|---|---:|
| `20260901T163031Z` | dry run | `ok` | 5,000 planned | 8 planned | inventory only |
| `20260901T163133Z` | apply | `ok` | 2,232 compressed; 2,768 already compressed | 7 held active; inactive T9 log rotated | +318,742,528 bytes |
| `20260901T163427Z` | scheduled apply | `ok` | 5,000 already compressed (pre-cursor fix) | 7 held active | -24,576 bytes |
| `20260901T163538Z` | apply after cursor fix | `ok` | 5,000 newly compressed | 7 held active | +768,532,480 bytes |

At the final observation D: had 85,513,957,376 bytes free. The two productive
passes recovered 1,087,275,008 bytes in-run. Background farm writes make a
single point-in-time drive delta non-authoritative; the append-only telemetry
is the durable source for the requested 24-hour trend.

No backup deletion was due: 90 backups remained inside the mandated retention
union and all 90 were already NTFS-compressed. No log older than 48 hours was
eligible. Both delete receipts therefore record zero requested/deleted files
and bytes after a successful live-DB quick check.

Receipts and hashes:

- `D:\QM\reports\state\continuous_retention\20260901T163031Z\run_summary.json`
  — SHA-256 `7EE80E5B0ABC717DEA057DAC59E1C7AD19276066303F16BAF5F6019DE96DCA87`
- `D:\QM\reports\state\continuous_retention\20260901T163133Z\run_summary.json`
  — SHA-256 `2023F0726688B332274693150E712177BF89F8D44961CF77B6C77496F3070C6E`
- `D:\QM\reports\state\continuous_retention\20260901T163427Z\run_summary.json`
  — SHA-256 `EF185F2ABA2929F1458E85E70E846C9C1FE8E89B549C8D7633AD04E6BDADBF43`
- `D:\QM\reports\state\continuous_retention\20260901T163538Z\run_summary.json`
  — SHA-256 `ACFD489AC75CEBF33080AC2C1287EEBFAF1BD561A6BD9A130D1E497FA5CD871E`
- `D:\QM\reports\state\backup_retention_continuous.jsonl`
  — snapshot SHA-256 `948CE1429CB2AF7F735AD332EFD91935877E308B9D153520A7449BF8ABDB9F9B`

## Verification

- Focused tests: `7 passed`.
- Python bytecode compilation: PASS.
- PowerShell parser: PASS.
- Scheduled invocation: result `0`, telemetry status `PASS`.
- Active-log behavior: all seven active candidates returned `HELD_ACTIVE`.
- Backup and log delete receipts: zero deletions, zero loss.
- Implementation commits:
  `878e2dce826b963ac0decfe27191c5bf4c6ab5d9`,
  `589b2110da030989760759877a0c6e13c00c84d4`, and
  `ac216b13137e19eedb04fbbaf3d5fba9e4e4bc70`.

## Backup production reuse decision

No 15-minute-wave backup reuse was enabled. Current backups are produced by
independent ceremony paths, and there is no shared restore-point identity and
freshness contract proving that one snapshot can safely serve all ceremonies.
Changing production semantics inside a retention ticket would risk stale or
misbound recovery evidence. Compression and age rotation are live now; backup
coalescing remains a separate OWNER-reviewed producer change.

## Review hold

The implementation and live controls satisfy the immediately testable parts of
the acceptance contract. A positive trend over a full 24-hour observation
window cannot be established during this single scheduled orchestration pass.
Review should use the telemetry JSONL after that window and must not infer a
verdict from the short in-run samples alone.
