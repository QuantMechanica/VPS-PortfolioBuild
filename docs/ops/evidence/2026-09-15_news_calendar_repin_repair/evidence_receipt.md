# Evidence receipt — news-calendar repin registry repair (prepared, not applied)

Prepared by: Kimi Code subagent, 2026-09-15 (read-only diagnosis + patch preparation).
House rule: OWNER-DEC-CALENDAR-REPIN (Sep 5) — dxz23 repins run through the governed flow,
**kein AI-Commit**. This patch is prepared for OWNER/Fable approval and application.

## Timeline

| When (UTC) | Event |
|---|---|
| 2026-09-12 03:31 | Receipt 000015 refresh binds calendar state A ("before"): primary sha `1a82f3f5…915d`, 48718 rows, coverage → 2026-09-12; secondary `0ce1802b…c70`, 48727 rows. |
| 2026-09-12 04:56:54 | Commit `76dca44dab` ("ops(news): bind refreshed calendar seed hashes") pins state A in `framework/registry/dxz23_execution_contracts.json` — 19 insertions / 19 deletions, calendar identity lines only. |
| 2026-09-15 02:45–02:47 | Scheduled `QM_NewsCalendar_Refresh` mints receipt **000016** (`d8683b53…`, created 02:47:15Z). Registry working tree updated to attested "after" state B: file sha `5a00ce07…`; primary `8744295a…16a46`, 48822 rows, coverage → 2026-09-19; secondary `3abc0cd3…a94`, 48831 rows. **Never committed.** |
| 2026-09-15 02:47–11:20 | Sep 15 commit storm: an **un-attested `git restore`** reverts the registry file to HEAD (state A). Registry mtime freezes at 11:20:27Z. |
| 2026-09-15 20:31:59 | Live calendars advance again: primary `c48ad8b4…c134`, 48825 data rows; secondary `e15b6fe1…3b935` (state C). |
| 2026-09-15 (later) | Next refresh's `record` **REFUSES**: registry pin (A) does not continue from the receipt-chain tail (B). Verified live today: `news_calendar_repin.py verify` → `REFUSED: receipt tail does not match current news_calendar_2015_2025.csv: sha256` (exit 2). |

## The three divergent states

| | A — before (HEAD / current registry) | B — receipt-16 attested after (lost in restore) | C — live CSV now (next pin) |
|---|---|---|---|
| primary sha256 | `1a82f3f5…c7915d` | `8744295a…16a46` | `c48ad8b4…a1c134` |
| primary rows | 48718 | 48822 | 48825 |
| primary coverage | → 2026-09-12 | → 2026-09-19 | (next receipt attests) |
| secondary sha256 | `0ce1802b…14c70` | `3abc0cd3…75da94` | `e15b6fe1…2f3b935` |
| secondary rows | 48727 | 48831 | — |
| registry file sha | `a95fd02c…c605d` (working tree = HEAD blob, git diff empty) | `5a00ce07…789ae8c` | — |

## Field classification (all 19 receipt-16 target objects, all identity fields)

- **REVERTED-TO-BEFORE: 19/19 objects → 38 field writes** (19× `sha256`, 19× `coverage_end`)
  across `$.contracts[23–26].calendar.sources[0–3]` and `$.contracts[27/30/31].data_dependencies[0]`.
- **OTHER-DIVERGENT: 0.** No target field differs from both receipt before and after.
- **ALREADY-MATCHES-AFTER: 19 field entries** (`coverage_start` = 2015-01-01, identical in
  both states). No receipt-16 after-value survives anywhere in the registry
  (whole-file scan: 0 occurrences of either after sha or of `2026-09-19`; the before
  shas and `2026-09-12` occur only at the 19 attested targets — 11 + 8 + 19 occurrences).

**Byte-level collateral finding.** Receipt-16 `before_file_sha256` (`c6a3ee79…`) does not
equal the current file bytes (`a95fd02c…`) under any CRLF/LF/trailing-newline variant, so
the Sep 12→15 working tree carried additional registry byte-delta beyond the calendar
pins. Recovery was attempted and failed: no matching copy in git commits/objects
(incl. dangling-blob scan, size-filtered), `.claude/worktrees` (28 copies, all = HEAD),
`git stash`, or `D:\QM` backups. That collateral is **unrecoverable and unenumerable**.
Receipt 16 attests its own diff was exactly the 19 calendar targets
(`changed_fields: [sha256, coverage_start, coverage_end]`, `policy_or_threshold_changes: 0`),
and `record()`/`verify_chain` compare parsed-JSON pins, never old file bytes — so the
38-field restore is necessary and sufficient for self-heal; the lost collateral does not
block it. OWNER may review session logs for what else was in flight Sep 12–15.

## Verification performed (read-only)

- `verify_patch_readonly.py`: all 38 `restore_to` values match receipt-16 `after` values
  byte-for-byte (re-read from receipt source); all 38 `current_value` match the live
  registry; in-memory render of the applier produces pins equal to the chain tail at all
  19 objects; replacement counts 11/8/19 exact. Result: **PASS** (exit 0).
- Registry sha256 identical before and after this whole preparation: `a95fd02c…`.

## Boundaries kept

- `framework/registry/dxz23_execution_contracts.json` **not modified** (sha `a95fd02c…`, git-clean).
- No receipts minted (chain tail remains 000016). `refresh_news_calendar.ps1` not run.
- `record` not invoked. Nothing committed or staged by this preparation.

## Approval requirement

Applying requires OWNER or Fable per OWNER-DEC-CALENDAR-REPIN (**kein AI-Commit**).
Apply command sequence and expected verification: `prepared_registry_patch.md`.
Machine-readable patch: `prepared_registry_patch.json`. Guarded applier (owner-run):
`apply_registry_patch.py`.
