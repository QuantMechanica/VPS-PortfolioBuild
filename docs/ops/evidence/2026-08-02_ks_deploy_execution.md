# KS vintage recompile — Sunday deploy execution record (§1 + §2)

- Executed: 2026-08-02, market-closed window (OWNER-approved in the signed packet)
- Base authority: `2026-07-31_ks_recompile_signature_packet.md` (OWNER signature
  2026-07-31 ~19:15Z: „passt alles, Sonntagsfenster bestätigt!")
- Addendum authority: `2026-07-31_10513_addendum_manifest.md` (OWNER signature
  2026-08-01 ~09:50 local: „klar akzeptier ich das, somit freigegeben")
- Operator: Claude (file-side deploy); OWNER (controlled T_Live re-init)
- Result: **§2 gate 10/10 PASS; KS coverage 13/24 → 23/24; zero dormant**

## Execution timeline (UTC)

| Time | Event |
|---|---|
| ~08:0x | First §1 attempt blocked fail-closed: registry tripwire fired (drift from signed 6fbebcd2d baseline). Read-only phase; nothing mutated. |
| ~08:1x | Fresh drift review (below) → tripwire rebound to reviewed current hashes. |
| ~08:15 | OWNER invoked the deploy script via the session `!` prefix. The bash pipeline suffix (`Tee-Object`) failed (`command not found`), so stdout was lost — but PowerShell executed the script to completion. |
| 08:23:01 | Deploy completion verified independently (all 8 targets = staged hashes; backups present). **DEPLOYMENT_EPOCH_UTC = 2026-08-02T08:23:01Z** (recorded anchor: after verified copy completion, before re-init). |
| ~08:20 | OWNER's second invocation (real PowerShell console) stopped fail-closed at phase 1 on the 10911 preimage check — correct behavior: the target already carried the new bytes. No double-mutation. |
| 08:24:21 | OWNER controlled T_Live re-init (DEINIT reason 9 across the book). |
| 08:24:26 | New binaries begin init (`SYMBOL_GUARD_INIT`, new `sv:1` log schema visible). |
| ~08:31 | Fresh `KS_BASELINE_LOADED` events detected; §2 gate run → **10/10 PASS**. |

## Registry-drift fresh review (packet exception clause)

The signed packet pinned the registry trio at the 6fbebcd2d baseline and
required "fresh review" on any pre-deploy drift. The tripwire fired; review
findings:

- `ea_id_registry.csv` `08dd4b43…` → `c623f73a…`: **+12 rows, 0 deletions**
  (build-lane EA registrations since 2026-07-31, e.g. 20192/20197/20198/20201).
- `magic_numbers.csv` `7ae5b6ff…` → `bc5334e5…`: **+23 rows, 0 deletions**.
- `QM_MagicResolver.mqh` `4c6fc13f…` → `876e5e16…`: deterministic regeneration
  from the appended CSV (SHA define, row count 15,366→15,420-class, arrays).
- All ten deploy magic rows (109110003, 109190001, 109390001, 111320000,
  114210000, 114210003, 125670003, 125670002, 129890003, 105130003) verified
  **byte-identical** old-vs-new, exactly one row each.
- The staged EX5 payload is baked at source pin 386151841 and is unaffected by
  on-disk registry growth.

Verdict: benign append-only growth; deploy identities untouched. The run
script's tripwire was rebound to the reviewed hashes so any *further* drift
before the copy would still block.

## Position/order preflight (addendum rider)

- Terminal journal 2026-08-02 09:11:57.114 local (restart sync, acct
  4000090541): **0 positions, 4 orders**.
- Pre-deploy pulse `live_book_pulse_predeploy_20260802.json` (07:44:12Z):
  `current_position_count=0`, `position_exposed=false` (terminal_sync).
- QM5_10513 short 3169829687 closed by `FRIDAY_CLOSE` 2026-07-31T17:59:56.781Z.
- None of the 4 account-wide pending orders maps to a deploy-target magic (no
  ORDER/PENDING placement events in any target EA log since 2026-07-25; latest
  11421 event is `TM_REMOVE_PENDING` 2026-07-31T13:09:48Z).

→ zero position/pending management consequence for any deploy identity; the
addendum's fail-closed rider was satisfied with this evidence.

## Deployed artifacts (all hash-verified post-copy)

Seven base EX5 (stage `ks_vintage_recompile_stage2_20260731_386151841`) at
their staged hashes per the bound manifest `ee12f509…`, plus the 10513
canonical EX5 `04b62af2…` (July-13 pin, Q10-PASS-bound), plus the two 10513
terminal-local baseline aliases (`edf01c12…`). Presets byte-identical. Rollback
preimages (7 + 1) at `C:\QM\deploy\KSRecompile_20260802_386151841\preimages*`,
each re-hashed OK against the recorded preimage values after the copy.

## §2 authoritative gate (epoch 2026-08-02T08:23:01Z)

Faithful Python implementation of the packet's §2 JSON verification (same
predicates; SHA via hashlib). Result rows:

| EA | symbol/tf | magic | loaded | absent | INIT_OK | EXEC_CONTRACT | NEWS | payload-hash==baseline | verdict |
|---:|---|---:|---:|---:|---:|---:|---:|---|---|
| 10911 | GDAXI/H1 | 109110003 | 1 | 0 | 1 | 1 | 1 | yes | PASS |
| 10919 | XTIUSD/H4 | 109190001 | 1 | 0 | 1 | 1 | 1 | yes | PASS |
| 10939 | GBPUSD/H4 | 109390001 | 1 | 0 | 1 | 1 | 1 | yes | PASS |
| 11132 | SP500/D1 | 111320000 | 1 | 0 | 1 | 1 | 1 | yes | PASS |
| 11421 | EURUSD/D1 | 114210000 | 1 | 0 | 1 | 1 | 1 | yes | PASS |
| 11421 | AUDUSD/D1 | 114210003 | 1 | 0 | 1 | 1 | 1 | yes | PASS |
| 12567 | XAUUSD/D1 | 125670003 | 1 | 0 | 1 | 1 | 1 | yes | PASS |
| 12567 | XNGUSD/D1 | 125670002 | 1 | 0 | 1 | 1 | 1 | yes | PASS |
| 12989 | XAUUSD/H4 | 129890003 | 1 | 0 | 1 | 1 | 1 | yes | PASS |
| 10513 | XAUUSD/D1 | 105130003 | 1 | 0 | 1 | 0 (per addendum contract) | 1 | yes | PASS |

Post-gate file integrity: 8 live EX5 = staged hashes; presets unchanged; all
baseline copies (three roots × sleeves) unchanged — PASS. The 10513 row
correctly has **no** `EXECUTION_CONTRACT` event (July-13 pin predates the
declaration call), exactly as the signed addendum contract requires.

## Post-deploy pulse

`live_book_pulse_postdeploy_20260802.json`: `loaded_ok=23/24; dormant=0;
missing_files=1; hash_mismatches=0; mirror_divergences=0`. The single missing
baseline is QM5_10440 (no Q10 PASS exists; honestly uncovered by design —
resting state until a Q10 PASS path or book retirement). Baseline sources:
21 terminal-local, 2 FILE_COMMON, 1 none.

Bundle items: 12778 chart restore — resolved (fresh `INIT_OK` 08:24:25Z,
AUDUSD/D1, magic 127780000). Swap-rate capture — **not executed**: no defined
capture mechanism exists; deferred as a follow-up, not silently skipped.

## Safety record

No AutoTrading change, no manual terminal64 start (re-init performed by OWNER
per the standing procedure), no T1–T10 interaction (factory was OFF in the
approved window), no preset/baseline rewrite beyond the two contracted 10513
terminal-local alias placements, no registry edit, no pipeline verdict
invented. Rollback remains available under the packet's separate-authority
clause with verified preimages.

## Open follow-ups

1. MNT-043 vintage bill (`1d448200…`): append-only overlay + Q06/Q07 rerun
   enqueues for the 9 admission identities — next step of this session.
2. 10440: needs a Q10 PASS path or book decision (unchanged).
3. Swap-rate capture mechanism: define and schedule (follow-up).
4. Factory_ON contract evolution (hold-release generation gap) — in progress,
   cross-review route.
