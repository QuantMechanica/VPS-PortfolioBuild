# 2026-08-14 — Archive-eater forensics (Claude pass, dual-forensics A-side)

**Status:** OPEN — root cause narrowed, USN ground truth pending (Codex B-side:
`forensics-archive-eater-multisym-20260814`). Factory claims paused via
FACTORY_OFF.flag (OWNER, ~08:40Z); containment engaged (auto re-trip 08:06:56Z).

## Two damage waves, different mechanisms suspected

**Wave 1 (overnight–05:10Z):** 9 files, T2/T3/T5/T7/T9. Watchdog kill/respawn
cycles ran in exactly this window; kill-mid-privatization was the working theory.
Restored from T1 (sha-verified) 05:14Z; governed release 06:35:58Z.
Evidence: `2026-08-14_containment_archive_restore_t2t3t5t7t9.md`.

**Wave 2 (06:35Z–08:06Z, NO kills, workers stable since 06:20 local):** 40+
files across T1/T2/T6/T7 — T7 alone 27 (AUDCAD/AUDCHF/AUDJPY/CADCHF/CADJPY/
CHFJPY … 2020-2022), even canonical-source T1 lost NZDCAD 2020/2021. Only 3
backtests completed in the window, ALL multisymbol baskets (QM5_12849/XTIUSD@T1,
QM5_20073/EURJPY@T10, QM5_1537/UK100@T3). Missing files are FX-cross years ==
basket legs. Kill-collateral CANNOT explain wave 2.

## Code-side facts (verified in source)

1. **Copy-on-claim privatization is atomically safe** — copy to temp → size+sha
   verify → `os.replace` (`custom_history_copy_on_claim.py:205-227`). It cannot
   leave the target absent, killed or not. It is NOT the deleter. (Wave-1
   attribution to kills is therefore ALSO in doubt — same eater likely.)
2. **Worker dispatch gate hashes only the claiming terminal's private inodes**
   (`custom_history_gate.py:536` passes `hash_private_terminals=(target,)`);
   foreign private files are STAT_ONLY. The docstring warns explicitly that
   read-opening a running terminal's archives causes sharing violations
   (`mt5_history_isolation.py:421-426`).
3. **Dangerous defaults exist**: `audit_history_isolation` defaults to
   `verify_archive_hashes=True, hash_private_terminals=None` (= full hashing of
   every terminal's private files). Production callers: only the scoped worker
   gate and the module CLI (`mt5_history_isolation.py:1049`, meant for
   quiescent full audits). If ANY process invoked the CLI (or my 05:14Z donor
   scan ran long) against a live fleet, it read-opens files running MT5s hold.
4. **MT5 journal smoking gun**: T7 `logs/20260814.log` 08:48:19 local
   (06:48:19Z, inside wave 2): `History 'CADCHF.DWX' file opening or reading
   error [32]` ×3 — sharing violation DURING a run; CADCHF year files
   subsequently missing. Error 32 means the file existed but was locked —
   consistent with MT5 discarding/rebuilding history it cannot open.
5. **ACL hardening is ABSENT on factory archives**: `icacls` on
   `T7\bases\Custom\history\CADCHF.DWX` (+ files) shows only inherited defaults
   (Administrators/SYSTEM F, Users RX/AD/WD) — no deny-delete. Nothing prevents
   terminal64/metatester64 (admin session) from deleting archive years. The
   08-09 `acl_apply_amended` artifacts must be compared (Codex item 4).

## Working root-cause model (to be confirmed/refuted by USN)

Restored-by-copy and privatized files are TERMINAL_PRIVATE inodes → the gate
hashes them (family hardlinks are STAT_ONLY) → some hasher read-opens a file
while that terminal's MT5 needs it exclusively (or vice versa) → MT5 hits
error 32 → treats the year file as unavailable/corrupt → deletes/rebuilds →
manifest gap → containment. Multisym runs multiply the exposed file set.

## Immediate consequences already applied

- Claims paused (FACTORY_OFF.flag, OWNER-set ~08:40Z); containment stays engaged.
- Restore SOP change for task #7: restore via `os.link` from T1 (family
  hardlink, same D: volume) — NOT `copyfile` — so restored files return to
  STAT_ONLY handling and shrink the hashed surface.
- Codex USN forensics dispatched (ground truth: which process deleted what when).

## Open questions (USN pass)

- Exact delete timestamps + originating process for wave-1 AND wave-2 files.
- Was the full-audit CLI (or any full-hash caller) active 06:35Z-08:06Z?
- Did the 2026-08-13 T8 incident (3 files) follow the same non-kill mechanism?
