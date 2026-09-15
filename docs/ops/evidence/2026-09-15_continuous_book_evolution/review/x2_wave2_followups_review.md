# Adversarial review — slice `x2_wave2_followups`

Reviewer: Fable (adversarial, read-only). Date: 2026-09-15.
Authority: OWNER-DEC-CBE-20260915 (wave-2 reviews E1/F1/G1/D1 + Kimi telemetry).
HEAD reviewed: `c30b121289d0bb40c25afdb44138dba5a7b8c5db`.
Patch: `scratchpad/patches_h/x2_wave2_followups.patch` (3122 lines, 31 files).

## Verdict: ACCEPT_WITH_FIXES

The substance is strong and, where checkable, real, deterministic and honest. Six directive
items are all implemented; touched tests pass (80 in the review re-run); §70 reproducibility
holds byte-for-byte; the sealed successor artifact verifies; no RED boundary is crossed. One
**blocking** mechanical apply-conflict on a generated doc must be resolved before commit, plus
a MAJOR honesty caveat on the Kimi telemetry headline.

---

## BLOCKING

### B1. `git apply --check` fails against HEAD (generated-doc hunk collision)
`git apply --check` returns exit 1:
```
error: patch failed: docs/ops/FTMO_CHALLENGE_READINESS.md:1
error: docs/ops/FTMO_CHALLENGE_READINESS.md: patch does not apply
```
Cause: the patch's base line is `Generated 2026-09-15T14:13:50Z`, but HEAD's file already
reads `Generated 2026-09-15T14:45:49Z` (the read-model doc was regenerated after the patch was
cut). **All 30 other files apply clean** (verified with `git apply --check --verbose`; every
other file prints `Checking patch …` with no error). This is a mechanical timestamp collision
on a machine-generated Markdown read-model, not a code/logic conflict.
**Fix before commit:** regenerate `FTMO_CHALLENGE_READINESS.md` via
`tools/strategy_farm/ftmo/challenge_readiness.py` after applying the rest, or drop/rebase that
single hunk. Per the review contract (conflicts = blocking) this is listed as blocking, but it
is trivially resolvable and does not reflect a defect in the change itself.

---

## MAJOR

### M1. Kimi telemetry steady-state is `auth_error` / local fallback, not `managed_usage_endpoint`
The report/summary headline claims `kimi_governor.py evaluate` yields
`usage_source = managed_usage_endpoint`, `quota_fetch_status ok`, `refresh_calls=1`.
Reproduced now (`kimi_governor.py evaluate`, patched worktree):
```
state=NORMAL ... flag=noop (real quota fetch auth_error -> local ledger fallback)
usage_source: local_ledger_fallback   quota_fetch_status: auth_error   refresh_calls: 0
```
The claim was true only **transiently**: the usage ledger carries exactly one
`role="quota_refresh"` line at `2026-09-15T15:12:36Z` (status ok) — so the bounded refresh
mechanism did fire once and was recorded correctly. But:
- the 15-min OAuth token is stale again and the interval guard caps refresh to ≤1 / 6 h, so
  authoritative telemetry is fresh only intermittently by design (directive sec31–33 accepts
  this as "the price of real telemetry"); and
- the scheduled `QM_StrategyFarm_KimiGovernor_15min` task runs the **canonical (uncommitted)**
  fetcher, so the bounded refresh does not run in production until this patch is committed. The
  live state now shows `refresh_calls: 0`, `refresh_last_utc: null` (interleaving of the
  unpatched scheduled writer with the patched one dropped the refresh bookkeeping).

Not a safety defect and the fallback path is well documented, but the reported telemetry
outcome is not the reproducible steady state. **Orchestrator action:** commit the patch before
relying on the fix; expect `managed_usage_endpoint` only in the short window after each ≤4/day
refresh, `local_ledger_fallback` otherwise.

---

## MINOR

### m1. `_change_concentration` largest-symbol note vs flag can disagree on suffixed keys
`is_largest_symbol` compares the bare (suffix-stripped) symbol, but the appended
`" (already the largest symbol)"` note uses raw `sym == top_symbol`. In the W38 data
`symbol_exposure_risk_pct` keys are bare (`XAUUSD`) so both agree; if those keys ever carry a
`.DWX` suffix the note and the flag could diverge. Cosmetic.

### m2. `finalize_ftmo_gap_campaign_v2.py` is not idempotent
It is a one-shot finalizer that already ran (0002 sealed, D: ledgers appended). Re-running
`remint(0001)` after 0002 exists would mint a further version or conflict. Fine as a one-shot;
document as such — do not wire it into any recurring task.

### m3. Independent non-Kimi critic not spawned for 0002
All agent_chain critic lanes were quota-gated (CLAUDE_DISABLED / CODEX_LOW_TOKENS /
AGY_LOW_QUOTA), so the cross-vendor critique fell back to Fable inline (non-Kimi vendor, but a
co-author of the mechanization). The caveat and fallback_reason are recorded honestly in
`critic_receipt.json` and the receipt. Acceptable per the honest-fallback instruction; re-run
through a spawned independent seat once a critic lane is off quota-hold.

---

## RED boundary: NOT crossed (verified)
- **No farm-DB writes.** heartbeat opens the DB `mode=ro`; grep of added lines shows no
  `INSERT/UPDATE/DELETE/commit/execute(mode=rw)`.
- **No gate-threshold / qualification changes.** The only "gate/threshold" matches are
  documentation lines asserting *no* gate/verdict write.
- **No T_Live / AutoTrading / FTMO-purchase / live-deploy code.** owner_action string in the
  read-model explicitly says these remain OWNER-only.
- **Sealed parent 0001 byte-unchanged.** `git status` clean for
  `strategy-seeds/sources/QM-RESEARCH-2026-0001/`; 0001 still lacks an H-CW card (confirms the
  G1 finding); supersession is lineage-only.
- **No dated-decision edits** (patch does not touch `decisions/`).
- **No token/secret leakage.** `kimi_quota_state.json` and the usage ledger contain no token
  substring (`access_token`/`refresh_token`/`eyJ` all absent); the never-print-token test
  passes.
- Research-ledger appends on `D:` (experiment_memory / search_history / research_source /
  usage) are additive (directive sec54).

## Positive verifications (reproduced)
- **§70 reproducibility (E1 M2 W38 re-run):** re-ran `recompose.py evaluate --venue dxz` on the
  existing `D:/QM/reports/book_evolution/2026-W38/dxz/snapshot` → read-model **byte-identical**
  to the live one (sha256 `4946992bd9df85…`); **outcome UNCHANGED = ADD_SLEEVE (add 10700
  XAUUSD)**.
- **E1 M2 concentration/dependence:** the XAUUSD concentration warning is explicit in both the
  read-model (`selected_alternative_risk_diagnostics.change_concentration_warnings`) and
  `evidence.md` ("change raises book exposure to XAUUSD from 2.3939% to 2.4714% (already the
  largest symbol)", share 22.47%). Dependence risk weighed as downside risk: hard guards pass,
  Δmean|downside-corr| = +0.0005 < 0.10 band → non-blocking (correct per directive sec8;
  advisory caps stay advisory, real economic dependence and the hard guard block).
- **E1 M1:** `_ftmo_demo_cycle` now reads only the manifest; freeze captures the readiness file
  with sha256; `load_snapshot` re-hashes it fail-closed. Tests
  `test_evaluate_byte_identical_across_change_to_live_readiness` and
  `test_load_snapshot_rehashes_readiness_capture` pass.
- **F1 M1+M2:** metrics carry canonical `trade_density_per_day` + `swap_cost` with old names as
  aliases; worst-across-cycles metrics present (`max_dd_pct_worst_cycle = -10.26`). Tests pass.
- **G1:** `research_source.verify(QM-RESEARCH-2026-0002)` → `ok=True, reasons=[]`, sha256
  `f6d39a23d5b45e…`; lineage `parent_version_id=QM-RESEARCH-2026-0001`, version 2;
  `is_authorized_author("multi-agent:Kimi+Fable")=True`; mechanization H-CW=PASS, H1/H2/H3=
  RETURN_TO_RESEARCH (honest); `.gitattributes` `QM-RESEARCH-*/** -text` rule present.
- **D1:** `book_evolution_health.json` carries the four keys with real values; heartbeat probe
  renders the "Buchentwicklungs-Gesundheit" section and raises RED/STALE flags. Tests pass.
- **Tests:** re-ran test_recompose_engine, test_ftmo_challenge_readiness,
  test_heartbeat_book_evolution_health, test_kimi_quota_fetcher, test_research_campaign_v2,
  test_kimi_governor → **80 passed**.

## Recommended next step
Resolve B1 (regenerate the FTMO readiness doc or rebase that hunk), commit with explicit
pathspecs (0002 store files byte-exact under the `-text` rule), then let
`QM_StrategyFarm_KimiGovernor_15min` pick up the committed fetcher so the bounded refresh runs
in production. Address M1 expectation-setting in the OWNER report; minors at leisure.
