# Pending worktree-path rows — REVIEW, dry run only

Task `b94dc07c-f28c-471d-ba8e-5fa2f17d764c`. Isolated proposal branch `agents/codex-worktree-paths-20260905`, commit `6299a263e2dfa8902e7454384029fe8da7952042`. All nine pending rows are covered; no existing row, successor, hold, setfile, binary, registry or worker was changed. Evidence is committed only on agents/board-advisor.

All nine canonical setfiles and all three canonical EX5 files exist. All nine canonical presets satisfy RISK_FIXED=1000 and RISK_PERCENT=0. Six QM5_10481 presets match their worktree bytes exactly. The two QM5_10141 differences are encoding/newlines only after UTF-8 BOM and newline normalization. QM5_10151 changes an actual assignment: `qm_magic_slot_offset=5` to `34`, together with magic-slot/build-hash comments. That row requires an identity review rather than a path-only substitution. Its path is under gemini-orchestration-1, correcting the brief’s all-Claude characterization.

## Complete pending-row inventory

| Work item | EA / phase / symbol | Worktree | Canonical preset | Comparison |
|---|---|---|---|---|
| `b7189709-abe5-4bff-ab28-d4f6a4fdd1e6` | QM5_10141 / Q02 / XAUUSD.DWX | `C:\QM\worktrees\claude-orchestration-2\framework\EAs\QM5_10141_rsi-meanrev\sets\QM5_10141_rsi-meanrev_XAUUSD.DWX_D1_backtest.set` | `C:\QM\repo\framework\EAs\QM5_10141_rsi-meanrev\sets\QM5_10141_rsi-meanrev_XAUUSD.DWX_D1_backtest.set` | ENCODING_OR_NEWLINES_ONLY |
| `f7950e47-85b7-43dd-bc5f-a67e27e75c6a` | QM5_10151 / Q02 / XAUUSD.DWX | `C:\QM\worktrees\gemini-orchestration-1\framework\EAs\QM5_10151_tv-ema-vwap-scalp\sets\QM5_10151_tv-ema-vwap-scalp_XAUUSD.DWX_M5_backtest.set` | `C:\QM\repo\framework\EAs\QM5_10151_tv-ema-vwap-scalp\sets\QM5_10151_tv-ema-vwap-scalp_XAUUSD.DWX_M5_backtest.set` | SETFILE_CONTENT_CHANGED |
| `adda1ec6-cc3e-4f60-b51f-2b566033adcb` | QM5_10481 / Q04 / AUDJPY.DWX | `C:\QM\worktrees\claude-orchestration-3\framework\EAs\QM5_10481_mql5-exec-ao\sets\QM5_10481_mql5-exec-ao_AUDJPY.DWX_M15_backtest.set` | `C:\QM\repo\framework\EAs\QM5_10481_mql5-exec-ao\sets\QM5_10481_mql5-exec-ao_AUDJPY.DWX_M15_backtest.set` | EXACT_BYTES |
| `85590a54-63e5-443a-8f17-2bee061483b1` | QM5_10141 / Q04 / EURUSD.DWX | `C:\QM\worktrees\claude-orchestration-2\framework\EAs\QM5_10141_rsi-meanrev\sets\QM5_10141_rsi-meanrev_EURUSD.DWX_D1_backtest.set` | `C:\QM\repo\framework\EAs\QM5_10141_rsi-meanrev\sets\QM5_10141_rsi-meanrev_EURUSD.DWX_D1_backtest.set` | ENCODING_OR_NEWLINES_ONLY |
| `1821432a-2f41-4417-b680-e3947b1c4ef7` | QM5_10481 / Q04 / AUDCHF.DWX | `C:\QM\worktrees\claude-orchestration-3\framework\EAs\QM5_10481_mql5-exec-ao\sets\QM5_10481_mql5-exec-ao_AUDCHF.DWX_M15_backtest.set` | `C:\QM\repo\framework\EAs\QM5_10481_mql5-exec-ao\sets\QM5_10481_mql5-exec-ao_AUDCHF.DWX_M15_backtest.set` | EXACT_BYTES |
| `7c137654-dcb4-44dd-9cbd-d233b75684b9` | QM5_10481 / Q04 / CADCHF.DWX | `C:\QM\worktrees\claude-orchestration-3\framework\EAs\QM5_10481_mql5-exec-ao\sets\QM5_10481_mql5-exec-ao_CADCHF.DWX_M15_backtest.set` | `C:\QM\repo\framework\EAs\QM5_10481_mql5-exec-ao\sets\QM5_10481_mql5-exec-ao_CADCHF.DWX_M15_backtest.set` | EXACT_BYTES |
| `995f36e9-b08c-4e28-aa77-5322cc419ecb` | QM5_10481 / Q04 / CADJPY.DWX | `C:\QM\worktrees\claude-orchestration-3\framework\EAs\QM5_10481_mql5-exec-ao\sets\QM5_10481_mql5-exec-ao_CADJPY.DWX_M15_backtest.set` | `C:\QM\repo\framework\EAs\QM5_10481_mql5-exec-ao\sets\QM5_10481_mql5-exec-ao_CADJPY.DWX_M15_backtest.set` | EXACT_BYTES |
| `0ff05819-1aab-42ff-a517-58724492c77b` | QM5_10481 / Q04 / AUDCAD.DWX | `C:\QM\worktrees\claude-orchestration-3\framework\EAs\QM5_10481_mql5-exec-ao\sets\QM5_10481_mql5-exec-ao_AUDCAD.DWX_M15_backtest.set` | `C:\QM\repo\framework\EAs\QM5_10481_mql5-exec-ao\sets\QM5_10481_mql5-exec-ao_AUDCAD.DWX_M15_backtest.set` | EXACT_BYTES |
| `b1384ee3-e582-46ce-8432-193b4865a854` | QM5_10481 / Q04 / EURNZD.DWX | `C:\QM\worktrees\claude-orchestration-3\framework\EAs\QM5_10481_mql5-exec-ao\sets\QM5_10481_mql5-exec-ao_EURNZD.DWX_M15_backtest.set` | `C:\QM\repo\framework\EAs\QM5_10481_mql5-exec-ao\sets\QM5_10481_mql5-exec-ao_EURNZD.DWX_M15_backtest.set` | EXACT_BYTES |

## Canonical binary identity

| EA | EX5 SHA-256 | File timestamp (UTC) |
|---|---|---|
| QM5_10141 | `917a93f0595c96ab1fb5a084e122969ea087f4e3a3b940b22471b389e4604f36` | 2026-07-14T20:34:08.885169+00:00 |
| QM5_10151 | `9cab68ef1e781ba5fa6fc52abb099e3066fe0a9991238d3ee97853236f667361` | 2026-06-16T07:54:58.398558+00:00 |
| QM5_10481 | `9485d89a40218bc2e58cfb5dc6dd88cb96787e48fc1f77ade2cdac5e695adb21` | 2026-07-14T20:46:39.748672+00:00 |

These timestamps are the canonical binary file modification times, **not independently proven compilation dates**. The work-item database has no COMPILE_EA receipt rows for these three old builds. No receipt-backed build date is invented; application must validate the current governed build before admitting a successor. [Inventory](2026-09-05_worktree_path_rows/inventory.json) contains full hashes, source row/payload digests, current holds, supersession state and per-row proposal receipts. Old and canonical preset bytes are frozen in deterministic gzip files.

## Exact proposal previews and append-only application contract

The existing `enqueue-backtest --append-only-rerun-of` path is not a generic path-rewrite dry-run command. It is a mutating enqueue interface, has no dry-run flag, and expects a terminal predecessor with valid phase lineage. These nine predecessors are still pending. The narrow false-INVALID canonical-setfile requeue helper only covers its governed terminal Q02 universe-expansion class; these rows do not qualify. Neither interface was invoked to manufacture a successor.

The proposal therefore supplies a mechanically read-only preview command and an explicit application contract. The following exact commands become available at the canonical path only after this branch is reviewed and integrated; their current implementation is in the isolated proposal worktree. They emit plans and cannot apply anything:

```powershell
python C:/QM/repo/tools/strategy_farm/canonical_setfile_paths.py preview --work-item-id b7189709-abe5-4bff-ab28-d4f6a4fdd1e6
python C:/QM/repo/tools/strategy_farm/canonical_setfile_paths.py preview --work-item-id f7950e47-85b7-43dd-bc5f-a67e27e75c6a
python C:/QM/repo/tools/strategy_farm/canonical_setfile_paths.py preview --work-item-id adda1ec6-cc3e-4f60-b51f-2b566033adcb
python C:/QM/repo/tools/strategy_farm/canonical_setfile_paths.py preview --work-item-id 85590a54-63e5-443a-8f17-2bee061483b1
python C:/QM/repo/tools/strategy_farm/canonical_setfile_paths.py preview --work-item-id 1821432a-2f41-4417-b680-e3947b1c4ef7
python C:/QM/repo/tools/strategy_farm/canonical_setfile_paths.py preview --work-item-id 7c137654-dcb4-44dd-9cbd-d233b75684b9
python C:/QM/repo/tools/strategy_farm/canonical_setfile_paths.py preview --work-item-id 995f36e9-b08c-4e28-aa77-5322cc419ecb
python C:/QM/repo/tools/strategy_farm/canonical_setfile_paths.py preview --work-item-id 0ff05819-1aab-42ff-a517-58724492c77b
python C:/QM/repo/tools/strategy_farm/canonical_setfile_paths.py preview --work-item-id b1384ee3-e582-46ce-8432-193b4865a854
```

Each preview binds one exact pending predecessor, its complete row and payload hashes, the canonical setfile and EX5 hashes, a deterministic proposed successor UUID and the original EA/phase/symbol. The collector executed that same proposal function against the canonical database with `mode=ro` and `query_only=ON`, producing all nine receipts. These are proposal/dry-run receipts, not approved source-repair authorities.

A governed application must revalidate the predecessor is still unclaimed/pending with identical row bytes, verify original phase/parent lineage and current build/risk/registry gates, refuse competing open successors, and preserve all non-path holds. Under one factory mutation lock, fresh OFF check and SQLite transaction, it must append a canonical successor plus a `work_item_supersedes` record excluding the old pending row from claims. It must not edit the predecessor path or verdict. Byte-changing cases bind both old and new hashes and require explicit authority. The tool intentionally has no apply operation; no safe existing mutating command satisfies this pending-row contract, so none is presented as runnable.

## Enqueue guard and verification

The patch guards the demonstrated producer, `sweep_enqueue_built_eas.insert_wi`, before insertion. It refuses foreign, relative, missing, escaped or non-EA-setfile paths; it resolves Windows junction/symlink escapes and accepts only canonical `framework/EAs/<ea>/sets/*.set` files. It reports refusals without removing deferred entries. It never silently rewrites a worktree path. This producer guard is not a claim that every legacy insertion path is now guarded.

**17 tests pass.** They cover canonical acceptance, foreign/relative/missing inputs, non-set files, symlink escape, unchanged predecessor bytes, unavailable/changed setfile equivalence, existing canary/fanout behavior, and an end-to-end foreign-path refusal that preserves its deferred entry. Positive test fixtures were moved into their declared canonical test repo; their behavioral assertions remain intact. [Test output](2026-09-05_worktree_path_rows/tests.json).

Review disposition: nine sealed proposals; six exact matches, two encoding-only differences, one actual magic-slot change; no apply. Claude/OWNER must resolve authority and build lineage before any successor is created.
