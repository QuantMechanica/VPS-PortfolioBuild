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

## ACL deep-dive (added ~09:20Z)

- The 08-09 hardening DID apply+verify an explicit deny ACE
  (Write|Delete|ChangePermissions|TakeOwnership for runner SID -500) on all
  3946 files (`acl_apply.json` 05:56Z PASS; amended2 16:42Z; verify_4 PASS).
- TODAY zero explicit ACEs exist on sampled files INCLUDING canonical T1
  (`T1\...\CADCHF.DWX\2018.hcc`: inherited defaults only). The hardening was
  stripped fleet-wide — prime suspect: the Variant-A per-terminal migration
  (08-10) created new inodes/copies that inherit directory defaults.
- **Detection hole:** when an `acl_evidence_path` is bound,
  `audit_history_isolation` REPLACES the live ACL probe with a static
  always-true stub (`mt5_history_isolation.py:998-1005`,
  `source: bound_acl_verification_receipt`) — the 08-09 receipt vouches
  forever; live erosion is invisible to every audit since.
- **Design contradiction:** re-applying deny-delete would BREAK copy-on-claim
  (its `os.replace` needs delete rights, and workers + MT5 run as the SAME
  admin identity). ACL hardening and claim-time privatization cannot coexist
  under a single runner identity. Fix options for cross-review:
  (a) split identities (MT5 processes vs workers) and deny only MT5;
  (b) privatize fully up-front per terminal, then hard-deny deletes fleet-wide
      (no claim-time replace needed anymore);
  (c) no ACLs; eliminate hash-vs-MT5 collisions and accept+auto-repair rare
      MT5 rebuild losses (fail-closed gate already catches them).

## Restore readiness (prepared, NOT yet applied)

49 missing instances = 32 distinct paths; ALL 32 have surviving FAMILY-inode
donors (manifest file_id match) — hardlink restore plan dry-run PASS
(`restore_hardlink_family.py`, scratchpad; evidence JSON on apply). Full
inventory: `D:\QM\reports\state\archive_missing_inventory_20260814.txt`.
No further losses since FACTORY_OFF.flag (~08:40Z) — damage is static.

## USN outcome + error-32 correlation (~09:45Z) — ATTRIBUTION CLOSED

- **USN journal on D: does not exist** (FSCTL error 1179; $Extend\$UsnJrnl absent;
  C: control has an active journal). No retroactive per-file deletion timeline is
  recoverable; no process auditing enabled. Journal absence itself is anomalous —
  cause undatable. Action: create the journal going forward.
- **Error-32 correlation across ALL affected terminals** (MT5 journals, UTF-16):
  per terminal, the set of symbols with `file opening or reading error [32]`
  matches the set of symbols with missing year files almost exactly
  (T1: NZDCAD=NZDCAD; T6: 6/6 exact; T7: 17 error-symbols ⊇ 15 loss-symbols;
  T2: 7≈6; T9: 6≈5). ALL terminals burst in the SAME window 08:46–08:51 local
  (06:46–06:51Z, the 10-wide claim wave after release); a second smaller cluster
  05:32–05:38 local matches wave-1 losses — **wave 1 was the same mechanism,
  not watchdog-kill collateral**.
- **Closed mechanism:** fleet-wide gate audits open a file handle on EVERY
  archive file of EVERY terminal (`file_identity` uses open() +
  GetFileInformationByHandle without delete/write share) → collides with the
  exclusive write-opens of concurrently RUNNING MT5 testers → MT5 gets
  error 32 on its own history file → discards the custom-symbol year file
  (no server to re-sync) → manifest gap → containment. Collision probability
  scales with concurrent runs (multisym waves), audit frequency, and the count
  of TERMINAL_PRIVATE inodes (post-restore/privatization hash load). The
  2026-08-13 T8 incident (3 files) fits the same class.

## Recovery ceremony record (~09:26Z) + authorization policy change

OWNER executed `dl085_recovery_ceremony.py` via `!`: fresh window attached,
containment released 09:26:00Z, **USN journal created on D:** (128 MB),
claim-pause flag removed. The receipt's `signature` field carried the literal
placeholder `<dein Signatur-Satz>`; authorization is nevertheless unambiguous
(OWNER personally executed the command interactively). Flagged to OWNER —
OWNER's response (same session, ~11:45 local) ratified a POLICY CHANGE:
**OWNER approvals are standing and unlimited; no per-incident hour-windows,
no signature sentences.** Implemented as a standing-unlimited authorization
artifact (pattern precedent: 2026-08-11 standing preparation decision), which
future receipts reference. The ceremony ran before the Codex max-effort
review verdict (OWNER's explicit call); review continues, findings applied
hot. Workers were bounced afterwards (old code resident since 06:20Z, no
self-reload) via watchdog heal so claims run the DL-085 path.
