# Path-to-25 Shadow Research Suite — 2026-08-24

> **Follow-up 2026-08-24:** The 23-sleeve Null Factory below is preserved as
> the first cohort-local result. It is now supplemented by the SHA-bound full
> 14,639-pair search-world sensitivity in
> `docs/ops/evidence/2026-08-24_shadow_null_full_search_world.md`; that wider
> test is fail-closed and does **not** accept the cohort-local p-value as a
> Factory-wide result.

Status: **COMPLETE WITH ONE FAIL-CLOSED RED-TEAM FINDING**

Authority: OWNER chat instruction on 2026-08-24

Canonical implementation commit: `d2e0ba733`

Mode: read-only/shadow research; not a gate, book, deploy, or live action

## Non-interference boundary

The work was developed in an isolated worktree and integrated as one explicit
commit. Production observations use SQLite `mode=ro` plus `query_only=ON`.
No work item, verdict, hold, queue priority, gate threshold, candidate pool,
book manifest, deployment state, terminal process, or AutoTrading state was
changed. The normal `QM_StrategyFarm_Cockpit_2min` scheduler performed the
dashboard render; it was not manually started or restarted.

## Reproduction commands

Run from `C:\QM\repo`:

```powershell
python tools/strategy_farm/path25_red_team.py --output D:\QM\strategy_farm\reports\shadow_research\2026-08-24_path25_red_team.json

python tools/strategy_farm/portfolio/shadow_booklab.py `
  --output D:\QM\strategy_farm\reports\shadow_research\2026-08-24_q15_shadow_booklab.json `
  --markdown D:\QM\strategy_farm\reports\shadow_research\2026-08-24_q15_shadow_booklab.md

python tools/strategy_farm/shadow_null_factory.py `
  --booklab-package D:\QM\reports\portfolio\invvol_stage1_20260804 `
  --output D:\QM\strategy_farm\reports\shadow_research\2026-08-24_null_factory_incumbent_roster.json

python tools/strategy_farm/strategy_gap_map.py `
  --output D:\QM\strategy_farm\reports\shadow_research\2026-08-24_strategy_gap_map.json `
  --markdown D:\QM\strategy_farm\reports\shadow_research\2026-08-24_strategy_gap_map.md
```

The Path-to-25 command returns exit code 1 because the observed binding defect
is deliberately classified as `FAIL`. The report is still written completely.

## 1. Path-to-25 red team

Snapshot time: `2026-08-24T08:27:31.595007+02:00`. Result: 13 PASS, 3 WARN,
1 FAIL. The hard failure is confined to three pending Q12 rows whose database
envelope says `v4/Q12`, while the SHA-bound routing payload still says `v3/Q14`
and binds manifest SHA-256
`988f9dea709bb71de5d7b6bce3c02ea02417cd63f447767853281c8f5f8fc6ce`
instead of the active v4 manifest SHA-256
`f71c1ea63f1e847b3670904a6de25bcb4b337df9e0a7cff8ee6405d9c3aa2c83`:

- `48183f09-ad48-5c42-b1b6-9e7787b5ac32`
- `8eda68d9-aae3-509c-a0cc-6e738e1bde99`
- `9975987c-d408-5724-8863-f4e49a214d4b`

Their artifact and parent hashes are present, but their active contract,
phase, and manifest identity are not truthful. They were intentionally left
untouched while the Factory is running.

Warnings are operationally unproven Q11/Q13/Q14 reach, zero currently qualified
Q14 pairs, and stale pre-activation labels (`PROPOSAL ONLY`, `READ_INERT`,
`DRAFT`) in the now-active v4 manifest. At the snapshot, Q09 had 31 done,
18 failed, and 243 pending rows; Q10_NEWS had 5 active, 11 done, 7 failed,
and 70 pending rows. Static/runtime routing, linear Q08→Q14 topology,
Q14→Q15 separation, OWNER-only book trigger, post-activation stamping, and the
absence of a Phase-3 bypass all passed.

## 2. Null Factory shadow audit

The supplied diagnostic cohort contains 23 analyzed incumbent sleeves over
2,348 synchronized days. It is explicitly **not** the loser-inclusive Factory
trial universe; one declared sleeve is excluded as `NOT_EXTRACTABLE`, and no
pre-evaluation cohort ledger exists.

Within that limited cohort, `QM5_10919_XTIUSD_109190001` is the selected maximum
with annualized Sharpe 0.93740967. The joint centered circular moving-block null
gives maxT/FWER p=0.0275; 2 sleeves survive maxT/FWER and 7 survive BH at 5%.
This is useful selection-bias diagnostics, but it is not full-Factory false-
discovery calibration and is never gate-eligible. The ledger schema now requires
both a frozen experiment specification and an explicit, bound all-declared-trials
cohort attestation before loser inclusion can be claimed.

## 3. Q15 Shadow BookLab

The source package is SHA-verified. It declares 24 sleeves; 23 are analyzed and
the Q10-FAIL `QM5_10440_NDX_104400003` remains an explicit exclusion. The panel
contains 2,348 synchronized daily observations from 2017-01-02 through
2025-12-31; the holdout contains 705 days.

- Equal weight holdout: Sharpe 2.89064901, max drawdown 1086.86086957 risk-PnL.
- Train-only inverse volatility holdout: Sharpe 3.66197363, max drawdown
  176.77922743 risk-PnL.
- Joint 1,999-run moving-block holdout bootstrap: Sharpe P05/P50/P95
  2.86678411 / 3.65753885 / 4.44757363; positive-total-PnL bootstrap fraction
  1.0.
- Canonical family-classification fallbacks: 0.

These are survivor-roster research counterfactuals, not proposed stop-risk
weights or a production-book decision. No manifest was emitted.

## 4. Strategy gap map

The read-only join parsed 3,228 OWNER-approved cards from 3,272 Markdown files,
observed 14,638 pipeline pairs across 2,983 EAs, and made zero queue/card changes.
Forty-one historical cards were narrowly recovered only because their YAML error
is located in an unrelated `source_citation` Windows path; invalid YAML in a
consumed field is refused.

All 20 feasible asset/archetype cells absent from the 23-sleeve reference roster
already have approved-card supply, while none has Q10+ supply. Therefore the
shadow diagnosis is `ADVANCE_AND_DIAGNOSE_EXISTING_APPROVED_SUPPLY`, not new
source intake. The largest actionable cell is FX/trend-following: 550 approved
cards, 25 with Q07+ evidence, and 0 with Q10+ evidence. This recommendation is
visibility-only and did not alter queue priority.

## Mission Control verification

The normal scheduler rendered
`D:\QM\strategy_farm\dashboards\cockpit_v2.html` at
`2026-08-24T08:26:56.3631133+02:00`. In the generated DOM,
`Linear gate frontier` occurs after `Ausnahmen &amp; Datenqualität`, and no further
`<section>` occurs after it. It is therefore the final dashboard section.

## Artifact bindings

| Artifact | SHA-256 | Bytes |
|---|---|---:|
| `2026-08-24_path25_red_team.json` | `5f937c84748180a2a1fdb99fafce6e31553737ac7481c354ac7ad6d2094ed838` | 11,622 |
| `2026-08-24_null_factory_incumbent_roster.json` | `f2eb77aff68a422df97bab9f36d0c4a0057fc518c4c07e15fa94907b571f6827` | 11,090 |
| `2026-08-24_q15_shadow_booklab.json` | `b25f75b2ce09d3b6cd65b56c51a898ae14e4f09d7243c4b8eb54bded84bab1dc` | 138,705 |
| `2026-08-24_q15_shadow_booklab.md` | `feb02446df2538abe3cfe820e1108b24373454dbc85a13bf3d07633c5f02f1bf` | 585 |
| `2026-08-24_strategy_gap_map.json` | `84577cbc482d119f5b3e040e34ebb36bfff0013676e476bec78f508c2d2daecf` | 72,027 |
| `2026-08-24_strategy_gap_map.md` | `57ece73918cd2bae472c5b147fa1341bb086e91948721cadc456c22009ef6bd6` | 2,353 |
| `cockpit_v2.html` at verification time | `ee34be5494fa872df9c54ef40773e362e183b8ab8b5e5ed5ced20a3fdfd938f3` | 2,195,950 |

The cockpit artifact is continuously regenerated, so its point-in-time hash is
expected to change while its layout invariant remains enforced by regression
test.

## Verification

- Canonical focused/related pytest set: `117 passed, 2 skipped` in 20.00s.
- Python byte-compilation: PASS.
- Ledger JSON Schema parses with PowerShell `Test-Json`: PASS.
- Commit whitespace validation (`git show --check d2e0ba733`): PASS.
