# Secondary finding from MNT-001: chk_ks_baseline_dormancy reads a stale manifest — fail-loud fix

Date: 2026-08-21. Author: Claude (orchestrator, headless cycle). Branch: agents/board-advisor.
Router task: `5c73b39f-b761-4e62-8428-50186b40ff48`.
Context: `docs/ops/evidence/2026-08-21_mnt001_10440_baseline_premise_invalid.md` §"Secondary finding".

## Manifest, reader, staleness — named

- **Manifest read:** `DXZ_BOOK_MANIFEST` (`health.py`), default
  `D:/QM/reports/portfolio/portfolio_manifest_live_24sleeve_20260724.json` (env-overridable
  via `QM_DXZ_BOOK_MANIFEST`).
- **Reader:** `chk_ks_baseline_dormancy()` — the KS-divergence-kill-switch dormancy health
  check. It binds every `manifest["sleeves"]` entry to an expected baseline hash and checks
  live QM logs for a matching `KS_BASELINE_LOADED` event.
- **How stale it can get:** unboundedly. The reader had no mechanism to notice a newer
  manifest existed anywhere. Confirmed live: `portfolio_manifest_live_24sleeve_20260724.json`
  (2026-07-24) is still the configured default, but
  `portfolio_manifest_sunday_FINAL24b_TOTALRISK12_20260726.json` (2026-07-25 22:03, i.e. newer)
  is the manifest explicitly named as *accepted* in
  `decisions/2026-07-26_book_final24b_minus10440_plus11422.md` — a ratified book decision that
  removed QM5_10440/NDX and admitted QM5_11422/USDCAD. The health check has been evaluating KS
  dormancy against a manifest a real book decision superseded almost a month ago, with no signal
  that anything was wrong.

## Decision: fail-loud, not bind-to-live

The ticket's acceptance offered either option. Binding the reader directly to "the live
manifest" was rejected here: the FINAL24b decision doc's own text says portfolio-construction
acceptance and the actual T_Live deployment (OWNER-approved preset write + AutoTrading flip)
are separate steps, and confirming which one T_Live is actually running requires live-account
verification — explicitly out of scope for an unattended health check / this task's authority
(ROT: "anything touching the live account/Darwinex book"). Committing to a specific "live"
manifest here could just as easily be wrong in the other direction if the deployment step never
happened. The safe, correct move is to surface the disagreement, not resolve it unilaterally.

## Fix

`_dxz_manifest_staleness()` (new, `health.py`) scans `DXZ_BOOK_MANIFEST`'s own directory for
sibling `portfolio_manifest_*.json` files newer than the configured one, excluding anything with
`DRAFT` in its name (staging/candidate files are not decision-book candidates). Wired into
`chk_ks_baseline_dormancy()`: when a newer sibling exists, its name and both mtimes are appended
to `detail` on every return path, and a check that would otherwise report `OK` is floored to
`WARN` (`manifest_stale`/`current`) — dormancy/coverage findings against a possibly-superseded
book are no longer silently reported as clean. FAIL and existing WARN paths keep their real
severity but gain the same staleness note plus an action hint pointing at `decisions/*book*.md`
and the `QM_DXZ_BOOK_MANIFEST` override.

This does not determine or change which manifest is live, touch T_Live, or write any manifest,
queue, or pipeline state. It only makes the disagreement visible in `health.json` where OWNER/
Claude will see it on the next report.

**Attribution note:** `_dxz_manifest_staleness` and its `utc_now_iso_from_ts` helper landed in
commit `9d90ef9a1` ("feat(health): derive per-phase work-item age SLOs") — a concurrent Codex
session editing the same file in this shared canonical checkout committed while this change was
mid-edit and swept it up alongside their own MNT-039 work. Content is correct and tested; the
commit message/authorship for that half of this change is Codex's, not mine. The
`chk_ks_baseline_dormancy` wiring in this commit is the remainder.

## Verification

New tests in `KsBaselineDormancyTest`
(`tools/strategy_farm/tests/test_health_vacuousness.py`):
- `test_stale_manifest_warns_even_when_otherwise_clean` — confirmed failing before the wiring
  fix (`git stash` bisection: an otherwise-clean fixture reported `OK` instead of `WARN`),
  passing after.
- `test_manifest_with_no_newer_sibling_is_not_flagged_stale` — no false positive when the
  configured manifest is genuinely current.
- `test_draft_sibling_manifest_never_counts_as_a_newer_candidate` — a newer `DRAFT`-named
  sibling is correctly ignored.

```
python -m pytest tools/strategy_farm/tests/test_health_vacuousness.py -q
39 passed
```

## Recommendation carried forward (Entscheidungsschlange, not executed here)

Confirm against T_Live (OWNER/Claude, live-account authority) whether FINAL24b is actually
deployed; if so, repoint `QM_DXZ_BOOK_MANIFEST` (or the default) at
`portfolio_manifest_sunday_FINAL24b_TOTALRISK12_20260726.json` and this WARN clears on its own.
