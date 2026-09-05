# E1-B1 governed candidate ingress — REVIEW

Task `3e3e903d-f03d-4f70-8f51-63efcf95159d`. Code `30524d22f94025c1d7ac068d5e7fdc22502adba3` on `agents/codex-news-candidate-ingress-20260905`. Implements verified candidate ingress, exact staged-pair reconciliation and a registered E1-A repin authority. **47 tests pass**, including mutation-free bad hash/failed gate refusals, exact create-only staging, fixture multi-plan compatibility, registered authority and refresh-parent refusal. PowerShell AST parse: zero errors. No production calendar, Common mirror, bundle, dxz23 record or enforcement flag was changed.

`candidate-ingress` validates the external manifest SHA, hash-bound verification JSON, all eight exact boolean PASS gates, schema/decision/publishability envelope, both canonical file hashes and parsed row counts. Links/reparse paths are rejected. Apply only creates a fresh `D:/QM/reports/state/news-calendar-staging-<32hex>` child and copies the already-verified bytes. The refresh skips weekly feed augmentation for this mode; normal multi-plan/publish/mirror/repin follows. Multi-plan rechecks the original candidate proof against the staged pair. The repin reason retains the candidate manifest hash. Existing production location and mutation-lock checks remain in force.

`--owner-decision-id` accepts the old `OWNER-DEC-CALENDAR-REPIN` and registered `OWNER-DEC-CALENDAR-E1A-20260905` only. Existing receipt chains still verify. The refresh requires E1-A authority with candidate ingress and retains the actual parent PID and operation proof for record; direct record without them is refused. No hand-edit of the contract registry is involved.

The 094500Z candidate's read-only diagnostic refused with: `candidate verification FAIL: 6.1_anchor_shares, 6.2_coverage, 6.3_cross_file_identity, 6.5_tick_footprints, 6.7_detector_clean`. The new E1-B2 candidate also refuses: `candidate verification FAIL: 6.1_anchor_shares, 6.2_coverage, 6.5_tick_footprints, 6.7_detector_clean`. All candidate file hashes remained unchanged. Running the production CLI from the isolated worktree separately refused its noncanonical path, as designed; the diagnostic used the new library with the canonical policy implementation. Production command availability requires Claude+OWNER integration first.

After integration and after a fresh pair passes all eight gates, CEO uses this one sequence (replace only the reviewed directory and exact manifest hash):

```powershell
$ErrorActionPreference = 'Stop'
$candidateDir = 'D:/QM/reports/news_calendar/repair_e1a/<VERIFIED_RUN>'
$candidateSha = '<REVIEWED_MANIFEST_SHA256>'
& C:/QM/repo/tools/strategy_farm/refresh_news_calendar.ps1 -CandidatePair $candidateDir -CandidateManifestSha256 $candidateSha -OwnerDecisionId OWNER-DEC-CALENDAR-E1A-20260905 -ReconciliationPlanOnly
if ($LASTEXITCODE -ne 0) { throw 'Candidate validation refused' }
& C:/QM/repo/tools/strategy_farm/refresh_news_calendar.ps1 -CandidatePair $candidateDir -CandidateManifestSha256 $candidateSha -OwnerDecisionId OWNER-DEC-CALENDAR-E1A-20260905
if ($LASTEXITCODE -ne 0) { throw 'Governed refresh/repin did not complete' }
python C:/QM/repo/tools/strategy_farm/news_calendar_repin.py verify
if ($LASTEXITCODE -ne 0) { throw 'Repin chain verification failed' }
```

That sequence has **not** been run for publication. Current candidates fail and must remain staged. Existing plausibility, publication proof, source coverage and runtime checks can still refuse a future pair; eight repair PASS gates are necessary, not a bypass of those checks. The 13 held news rows remain held, and any later release requires pipeline evidence through its normal governed close-out.
