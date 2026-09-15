# Adversarial Review — Slice `i1_strategy_wiki_sync`

Reviewer: Claude (adversarial reviewer seat), 2026-09-15
Patch: `scratchpad/patches_i/i1_strategy_wiki_sync.patch` (2159 lines, 9 files)
Target: `C:/QM/repo` HEAD `4aaedf94dba0fcc8d8ae2b389b4b643101ad43ac` (`agents/board-advisor`)

## Verdict: ACCEPT

The slice is real, deterministic, idempotent and honest. The RUN-FOR-REAL numbers
in the report reproduce byte-for-byte from live inputs. RED boundaries were respected.
No blocking or major findings. A handful of minor notes below (none require a fix to
accept).

## What was verified

### Patch applies cleanly
- `git apply --check` against HEAD → **exit 0** (no conflicts). New files not yet in
  canonical repo (expected; implementer delivered a patch, no commit).

### Live artifacts are real and match the report exactly
- `D:/QM/reports/state/strategy_wiki_sync.json`: `STRATEGY_WIKI_SYNC = GREEN`,
  `canonical_records=3820`, `valid_projections=3820`, `projected_nodes=5265`,
  `record_count=5265`, every count in {missing,stale,duplicate,orphan,invalid_link,
  unresolved_source,unresolved_lineage} = 0. Class counts ACTIVE 3820 / DRAFT 130 /
  RETIRED 356 / REJECTED 893 / DUPLICATE 7 / SUPERSEDED 4 / HISTORICAL 55 — identical
  to the report's §2 table.
- Vault `09 Strategy Wiki/generated/`: physically present, **5,265 `.md` nodes** across
  the 7 class folders (counts confirmed per-folder), plus `_INDEX.md` and
  `.sync/state.json`. Sidecar shows a converged state (written 50 / skipped 5215 /
  pruned 4), consistent with the documented "lineage_map landed mid-build, re-build
  converged" sequence.
- Hand-written `strategies/` = **45 nodes, untouched**. Root `_INDEX.md` carries exactly
  one `STRATEGY_WIKI_SYNC:BEGIN` marker block; hand-written preamble preserved.
- id-less nodes (`ea_id: NOT_APPLICABLE`) = **105**, matching the report's
  "cards without EA id = 105".

### Idempotency & determinism — PROVEN against live inputs
Ran the generator twice writing to a throwaway `QM_VAULT_ROOT` temp vault (reads real
repo + `D:` cards / registry / pipeline / books / lineage, writes local temp so the
cloud vault is not touched):
- Build 1: `written=5265, skipped=0`, class counts identical to live.
- Build 2: `written=0, skipped=5265, pruned=0` → byte-identical, no cloud-sync spam.
- `lint` on the temp vault: `GREEN`, canonical 3820 / valid 3820 / projected 5265 —
  reproduces the live headline numbers from scratch. This is strong evidence the
  reported figures are measured, not invented.

### Honesty of node content
Inspected sample nodes (e.g. `ACTIVE_CANONICAL/QM5_10000_ff-tasayc-cci-breakout.md`):
explicit `NOT_EVALUATED` / `UNKNOWN` / `NOT_APPLICABLE` / `EVIDENCE_MISSING` tokens used
throughout; no fabricated gate/verdict/hash values; `card_hash` and per-node
`inputs_sha256`/`last_sync_inputs_sha256` present and equal (per §7 idempotency design).
No wall-clock in node bodies (wall-clock lives only in sidecar + health read-model).

### Tests
- 16 new tests pass (`test_strategy_wiki_sync.py` 11, `test_vault_paths.py` 5).
- Regression sample re-run: `test_factory_bottleneck_readmodel.py` +
  `test_mission_control_v2_data.py` → 30 passed.

### D1 fix (research_dedup_check wrong vault root)
`framework/scripts/research_dedup_check.py` now resolves
`DEFAULT_WIKI_VAULT = G:\My Drive\QuantMechanica - Company Reference\09 Strategy Wiki`
via the shared `vault_paths.strategy_wiki_root()` (was missing the
`QuantMechanica - Company Reference` segment → fail-closed since inception). Import shim
works from arbitrary cwd; `sys` is imported. Verified by importing the module and
printing the resolved path.

### RED boundary check — all respected
- Scheduled task `QM_StrategyFarm_StrategyWikiSync_60min` **NOT registered** (confirmed
  via `Get-ScheduledTask` → absent). Installer written only, as claimed.
- No touches of gate thresholds, gate manifests, qualification weakening, T_Live /
  AutoTrading / FTMO-purchase / live deployment, `decisions/` dated files, or secrets
  (grep of the patch for these terms → empty).
- No hand-written vault page overwritten; no vault page deleted except generator-owned
  nodes (frontmatter `generator: strategy_wiki_sync/v1`) via class/rename pruning —
  verified by the untouched 45 `strategies/` nodes and the prune guard in
  `_prune_stale_generated`.
- No new farm-DB writes introduced (the pre-existing `event(...)` in `approve_card` is
  unchanged; the post-approve hook only projects a vault node and is wrapped so it can
  never fail an approval).
- `os` / `update_card_frontmatter` / `_sha256_file` / `prior_card_sha256` all exist in
  `farmctl.py`; the additions reference only real symbols.

## Minor notes (non-blocking; no fix required to accept)

1. **`ACTIVE_CANONICAL` names card-approval state, not pipeline-pass or live status.**
   e.g. `QM5_10000` is `ACTIVE_CANONICAL` while its node truthfully shows
   `pipeline_status: BLOCKED`, `terminal_verdict: BLOCKED`, `current_blocker: Q04:FAIL`.
   The per-node fields are unambiguous, and the §5 mapping rule is documented, but a
   reader skimming only the index class labels could over-read "ACTIVE". Consider a
   one-line clarifier in the generated `_INDEX.md` header. Cosmetic.

2. **`card_sha256` name overload in `approve_card`.** The persisted frontmatter
   `card_sha256` is the self-excluding *content* hash (`card_file_content_sha256`), while
   the return-dict `card_sha256` remains the raw *file* hash (`_sha256_file`). Two
   different values under one name. Functionally fine (the wiki-sync staleness uses the
   self-excluding content hash consistently); worth a rename for clarity later.

3. **`research_dedup_check` vault-side dedup runs for the first time.** Fixing D1 means a
   previously-dead check is now live; its next run may surface dedup findings that were
   silently skipped before. Intended by the directive, but a behavioral change to expect.

4. **Post-approve hook (`--only`) skips prune**, so a slug/class change applied through
   the hook can leave a lingering old-named node until the next full build (which the
   60-min task runs and self-converges). Documented in the implementer notes.

5. **Pre-existing (not introduced here):** `_sha256_file` is defined twice in
   `farmctl.py` (lines 8152 and 15856). Out of scope for this slice.

## Follow-ups the orchestrator still owns (correctly deferred, per report §"NOT done")
- Register `QM_StrategyFarm_StrategyWikiSync_60min` (SYSTEM) via the installer.
- Wire external (non-QM-RESEARCH) `source_hash` from the vault `sources/*.md` graph
  (currently `EVIDENCE_MISSING`, honest; does not affect GREEN).
- Commit/push the patch (orchestrator's act).

## Evidence
- `D:/QM/reports/state/strategy_wiki_sync.json` (GREEN, live)
- `G:/My Drive/QuantMechanica - Company Reference/09 Strategy Wiki/generated/` (5,265 nodes)
- `.../09 Strategy Wiki/generated/.sync/state.json` (converged sidecar)
- Idempotency temp run: `scratchpad/idemp_vault/` (build1 5265 / build2 0, lint GREEN)
- worktree `C:/QM/repo/.claude/worktrees/wf_7604e910-390-1` (16 new + 30 regression tests pass)
