# 2026-08-15 — Archive-eater forensics (Claude, independent side of dual review)

Status: written BEFORE reading the Codex report (task bc487116) per the
dual-forensics doctrine. Cross-review section to be appended.

## Verdict

The "archive eater" is not a daemon, a purge task, or an integrity defect —
it is the **residual DL-085 mechanism applied to bystander symbols**:

1. Copy-on-claim privatizes only the claimed host + declared basket symbols
   (`terminal_worker._privatize_custom_history_claim`). Every OTHER symbol in
   a terminal's `Bases\Custom` still shares family inodes across T1-T10.
2. A booting MT5 tester scans ALL custom symbols, not just the claimed one.
   When two terminals boot near-simultaneously, both open the same shared
   bystander inode; one open is exclusive → `error [32]`
   (ERROR_SHARING_VIOLATION) → MT5 discards the year file.
3. The next claim's worker gate finds `MANIFEST_ARCHIVE_FILE_MISSING` and
   repairs from the verified master — which is why every receipt in 48h is
   `REPAIRED_VERIFIED` and **no file was ever lost twice on the same
   terminal**: self-heal works; the losses are transient boot collisions.

## Evidence chain (all paths verifiable)

- `D:\QM\strategy_farm\state\custom_history_repairs.jsonl`, last 48h =
  117 receipts, decomposing into:
  - 49 × `claude_dl085_mass_restore_20260814` (the recovery itself, 09h) —
    not losses;
  - 52 × one `worker_gate:T8` fleet sweep at 16:42Z on 2026-08-14 —
    bystander FX-cross/index year files across T1-T5, T9;
  - ~13 organic singles; **only 3 on 2026-08-15** (AUDCAD 2017/2018 on T4,
    AUDCAD 2019 on T6).
- **Process attribution** (MT5 journals): `D:\QM\mt5\T4\logs\20260815.log`
  12:06:38.351/.353 and `D:\QM\mt5\T6\logs\20260815.log` 12:06:38.854 —
  `'AUDCAD.DWX' file opening or reading error [32]` within 503 ms of each
  other, on a symbol NEITHER terminal was testing (T4: AUDJPY run, T6:
  SP500 run), 90 s before the 10:08:01Z gate repairs of exactly those files.
- Same pattern for the big sweep: `D:\QM\mt5\T5\logs\20260814.log` has 25
  error-32 events; the 18:39 local cluster (UK100, SP500, AUDCAD ×2,
  AUDCHF …) precedes the 16:42Z repair sweep by 3 minutes, right after the
  fleet went 10-wide (~15:57Z). The 23:47-48 local events (GBPAUD,
  GBPCAD ×2) are exactly the files whose 21:49:40Z repair race then produced
  the PARTIAL that tripped containment (self-trip #3).
- Loss rate tracks boot concurrency: 10-wide unstaggered ramp → 52 losses;
  today under the 60s claim stagger → 3. The stagger shipped for RAM
  reasons (6dcb202df) and independently suppresses this mechanism.

## Why the health check screams anyway

`custom_history_repairs_24h` counts ALL receipts in 24h, including the
mass-restore's 49 and the one-time sweep's 52 → "114/24h FAIL" while the
organic loss rate is ~3-13/day and fully self-healing. Fixed alongside this
report: the counter now counts only organic `worker_gate:*` receipts.

## Fix options for cross-review (not yet implemented)

- **A (preferred): bystander trim at claim time.** Remove non-claimed symbol
  archives from the terminal's `Bases\Custom` during copy-on-claim instead of
  leaving shared inodes exposed; the repair-first gate already restores any
  symbol from master when a later claim needs it. Requires the gate/manifest
  contract to treat absent bystanders as normal, not as findings — an
  architecture change at the DL-085 heart, needs both forensics to agree.
- **B: accept-and-monitor.** The mechanism is self-healing, master-backed,
  and stagger-suppressed; with the health counter fixed, remaining noise is
  ~3-13 repairs/day. Zero code risk.
- Not viable: full-fleet physical privatization (≈87 GB × 10 terminals
  exceeds D: free space).
