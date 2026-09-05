# CEO audit integration — 2026-09-05

Source: Codex Factory-CEO-Audit (Vault `08 Current State/Audits/2026-09-05 Factory CEO Audit/`, analysis-only, fingerprints in `04 Quellenfingerprints.json`). OWNER 2026-09-05 ~10:50Z: "Takte diese Punkte und Analyse bitte ebenfalls ein". This page maps the fifteen measures to router tasks; `agent_tasks` is the authority. Written 10:53Z.

## Verdict on the audit

- The audit's central judgement matches the CEO position of today: the bottleneck is turning research stock into decision-grade, executable, economically meaningful evidence — not more EAs, not a rebuild. Its four headline findings were already partly in flight (calendar E1-A/E1-B, OOS window contract fix, readiness F5, acceptance test) and are now completed by dedicated tasks for the gaps it names (DSR wiring, evidence loss, live identity, attribution, joint risk telemetry, cost pack, restore, ledger, board).
- Two audit recommendations are NOT adopted as stated: (a) "Website / Build in Public stays deferred" — superseded by the OWNER's explicit order of the same day (website rework in progress, deploy only by Mission-Control card); (b) the audit's note that the 25-pair counter is "no proof of return" is accepted, but the counter stays the OWNER-defined drive target (OWNER-DEC-A1) until the M01 release-status projection and the M11 cohort card replace it.
- ROT stays ROT: DSR activation (M04), live identity attestation/signing (M06), the release cohort definition (M11) and the economic test contract (M13) are delivered INERT with a Vorlage each and become Mission-Control cards; nothing in this integration changes a gate threshold, a verdict, the candidate pool or the live book.

## Measure map

| ID | Prio | Measure | Status / task | Boundary |
|---|---|---|---|---|
| M01 | 0 | Canonical release status / contiguity contract | NEW 40812f0b (Codex Sol high) | projection read-only; OWNER-DEC-DL082-EXT Option D unchanged |
| M02 | 0 | Calendar correct and fresh | IN FLIGHT: E1-A delivered (8eb9f74b, verification FAIL), E1-B1 3e3e903d control plane, E1-B2 07add720 data + headless T_Export exports; freshness = weekly refresh | OWNER handstep at the end: Q09 correction receipt |
| M03 | 0 | Re-evaluate affected evidence, run the OOS window correctly | DONE code: window contract + repair-oos-window (1ac9f653d8); E2/E4 parked (90431302/49a8c88b) until the corrected calendar is resealed; acceptance rule (native report window + consumed hashes) added to the E4 ticket by this integration |  |
| M04 | 0 | DSR/statistics effective and correct | NEW 9fa50c9d (Codex Astra xhigh): corrected DSR INERT behind QM_DSR_V2 + additive evidence-status projection + Vorlage | activation = OWNER card (gate logic) |
| M05 | 0 | Release evidence stays findable (750/1,205 missing, +32/day) | NEW 7ef6444b (Codex Sol high): adjudication vs DL-090 receipts/purge logs/archive; purge exclusions after dry run |  |
| M06 | 0 | Live identity without the freeze circle | NEW ebe10705 (Codex Sol high): attest-current transition INERT + Vorlage | activation/signing = OWNER card |
| M07 | 0 | Money and provider status verified | NEW 3a20271f (Codex Sol medium): cash ledger v1 from local sources + OWNER export checklist | OWNER supplies FTMO/DXZ portal exports |
| M08 | 1 | FTMO costs and execution comparable | NEW 0cb1153d (Codex Sol high): cost-version file + consumer wiring from data on disk | broad backfill: Dukascopy card due 2026-09-14 |
| M09 | 1 | Joint account-risk control + telemetry proven | NEW 3d2c9e2f (Codex Sol high): scenario matrix on the isolated lane with the sealed target binaries |  |
| M10 | 1 | Burn-in / attribution correct | NEW b94b61c5 (Codex Sol high): position-lifecycle attribution, magic-0 resolution, KS gap, silent sleeves, EOD/intraday-low series |  |
| M11 | 1 | Bounded release cohort and meaningful optimisation | NEW 93cd0e1c (Codex Astra xhigh): utility check + cohort contract Vorlage; running: D1 pre-screen active (97bebb43f5), retro-skip c3779c25 | cohort definition = OWNER card (ROT: candidate pool) |
| M12 | 1 | Two venue-specific portfolio experiments | PARKED with dependencies M03/M04/M08/M11 (+M09 execution evidence); ticket when M11 cohort is decided |  |
| M13 | 1 | Economic test contract | NEW 1bf87710 (Codex Astra xhigh): Vorlage separating the bounded learning trial from the long-run claim; r5 stays ratifiable (MC card OWNER-DEC-FTMO-ACCEPTANCE-TEST-R5-20260905) | OWNER card after the Vorlage |
| M14 | 1 | Restore and storage reliable | NEW 18b6e054 (Codex Sol medium): isolated restore test, RPO/RTO, retention lock fix, thresholds |  |
| M15 | 2 | Action-guiding board and net KPI | NEW 8db1d722 (Codex Sol medium): task projection + net-KPI strip on Mission Control v2 | values from M07/M01 or UNKNOWN |

## Pacing

- Priority-0 tasks first (M04, M05, M01, M06), then M10/M09/M08, then M14/M07/M13/M11/M15; the router paces Codex Sol/Astra against the 5-hour and weekly limits; backtests are never throttled.
- OWNER items (vault OWNER board): FTMO/DXZ portal exports for M07; the cards that will follow the Vorlagen (DSR v2 activation, live identity attestation, release cohort, economic test contract).

## Evidence

- Audit package: the five files above (read-only). Integration receipt: this page + `docs/ops/OPEN_ITEMS_STATUS.md` addendum 10:53Z.
