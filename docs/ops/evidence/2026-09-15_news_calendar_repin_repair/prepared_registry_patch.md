# Prepared registry patch — news-calendar repin repair (2026-09-15)

**Status: PREPARED, NOT APPLIED.** Authority: OWNER-DEC-CALENDAR-REPIN — *kein AI-Commit*.
OWNER or Fable reviews and applies. Nothing below has been executed against the registry.

## What happened (one paragraph)

Receipt 000016 (2026-09-15T02:47Z) attested the registry repin to the refreshed calendar
identity (primary sha `8744295a…16a46`, coverage to 2026-09-19). That registry update lived
only in the working tree; an un-attested `git restore` during the Sep 15 commit storm
reverted the file to HEAD (Sep 12 pin state, primary sha `1a82f3f5…915d`, coverage to
2026-09-12). The live CSV has since moved again (20:31Z, sha `c48ad8b4…c134`), so the
scheduled refresh's `record` now REFUSES: the registry pin no longer continues from the
receipt-chain tail. Fix: restore the 19 attested calendar-identity fields, then let the
next scheduled refresh mint receipt 000017. The chain self-heals.

## Classification of the 19 receipt-16 target objects (55-field scan)

| Class | Count |
|---|---|
| REVERTED-TO-BEFORE (need restore) | 19 objects → **38 field writes** (19× `sha256`, 19× `coverage_end`) |
| OTHER-DIVERGENT (differs from both before and after) | **0** |
| ALREADY-MATCHES-AFTER | 19 field entries (`coverage_start` = 2015-01-01, unchanged in both states) |

Full field list: `prepared_registry_patch.json` → `reverted_to_before_fields`.

## Apply (OWNER/Fable, ~5 minutes)

```bat
cd C:\QM\repo

:: 1. Re-verify the artifact against sources (read-only; takes seconds)
python docs\ops\evidence\2026-09-15_news_calendar_repin_repair\verify_patch_readonly.py
::    expect: "status": "PASS", "fields_checked": 38, "failures": []

:: 2. Apply the guarded patch (atomic write; refuses unless every guard passes)
python docs\ops\evidence\2026-09-15_news_calendar_repin_repair\apply_registry_patch.py
::    expect: "status": "APPLIED", "fields_restored": 38
```

The applier guards: current values must match the patch (G1), exact replacement counts
11 primary-sha / 8 secondary-sha / 19 coverage_end (G2), post-render fields equal
`restore_to` (G3), post-render pin equals the receipt-16 tail at all 19 objects (G4).
It edits only `framework/registry/dxz23_execution_contracts.json`, byte-preserving.

## Expected post-apply verification

1. `python tools\strategy_farm\news_calendar_repin.py verify`
   → still `REFUSED: receipt tail does not match current news_calendar_2015_2025.csv: sha256`.
   **This is expected and correct** immediately after the patch: the tail is the 02:47Z
   calendar, the live CSV is the 20:31Z calendar. (Verified in this state today.)
2. Let the scheduled `QM_NewsCalendar_Refresh` run — **do not hand-run `record`**. It
   accepts the precondition (pin == tail), re-renders the registry to the live bytes, and
   mints receipt `000017` binding primary `c48ad8b4…c134` / secondary `e15b6fe1…3b935`.
3. After 000017 exists: `verify` → `{"ok": true, "status": "PASS"}`. Chain self-healed.

## Notes

- Committing the patched registry is the OWNER's call (kein AI-Commit). Natural point:
  together with receipt 000017's attestation, as was done for prior pins.
- Byte-level caveat: the receipt-time registry bytes (before `c6a3ee79…`, after
  `5a00ce07…`) are unrecoverable — the un-attested restore also destroyed any other
  working-tree registry edits from Sep 12–15. Receipt 16 attests its own diff was exactly
  the 19 calendar targets (`policy_or_threshold_changes: 0`), and `record()` compares
  parsed-JSON pins, not old file bytes — so the restore above is necessary and sufficient.
  See `evidence_receipt.md`.
